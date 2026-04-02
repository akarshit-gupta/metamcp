import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { Transport } from "@modelcontextprotocol/sdk/shared/transport.js";
import express from "express";

import {
  ApiKeyAuthenticatedRequest,
  authenticateApiKey,
} from "@/middleware/api-key-oauth.middleware";
import { lookupEndpoint } from "@/middleware/lookup-endpoint-middleware";
import { rateLimitMiddleware } from "@/middleware/rate-limit.middleware";
import logger from "@/utils/logger";

import { logIncomingPublicMetamcpHeaders } from "../../lib/metamcp/log-incoming-headers";
import { metaMcpServerPool } from "../../lib/metamcp/metamcp-server-pool";
import type { MetaMcpUserContext } from "../../lib/metamcp/user-context-store";
import {
  getUserContextForSession,
  removeUserContextForSession,
  setUserContextForNamespace,
  setUserContextForSession,
} from "../../lib/metamcp/user-context-store";
import { SessionLifetimeManagerImpl } from "../../lib/session-lifetime-manager";

const sseRouter = express.Router();

const getHeaderString = (
  value: string | string[] | undefined,
): string | undefined => {
  if (!value) return undefined;
  return Array.isArray(value) ? value[0] : value;
};

/** LibreChat often sends literal {{LIBRECHAT_USER_*}} on SSE GET before substitution; POST /message has real values. */
function isUnresolvedLibreChatPlaceholder(value: string | undefined): boolean {
  if (!value) return false;
  return value.includes("{{") && value.includes("}}");
}

function userHeadersFromRequest(req: express.Request): {
  userId?: string;
  userEmail?: string;
  userRole?: string;
} {
  const rawId = getHeaderString(req.headers["x-user-id"]);
  const rawEmail = getHeaderString(req.headers["x-user-email"]);
  const rawRole = getHeaderString(req.headers["x-user-role"]);
  return {
    userId: isUnresolvedLibreChatPlaceholder(rawId) ? undefined : rawId,
    userEmail: isUnresolvedLibreChatPlaceholder(rawEmail) ? undefined : rawEmail,
    userRole: isUnresolvedLibreChatPlaceholder(rawRole) ? undefined : rawRole,
  };
}

function stripUnresolvedUserFields(ctx: MetaMcpUserContext): MetaMcpUserContext {
  return {
    ...ctx,
    userId:
      ctx.userId && !isUnresolvedLibreChatPlaceholder(ctx.userId)
        ? ctx.userId
        : undefined,
    userEmail:
      ctx.userEmail && !isUnresolvedLibreChatPlaceholder(ctx.userEmail)
        ? ctx.userEmail
        : undefined,
    userRole:
      ctx.userRole && !isUnresolvedLibreChatPlaceholder(ctx.userRole)
        ? ctx.userRole
        : undefined,
  };
}

// Session lifetime manager for SSE sessions
const sessionManager = new SessionLifetimeManagerImpl<Transport>("SSE");

// Cleanup function for a specific session
const cleanupSession = async (sessionId: string, transport?: Transport) => {
  logger.info(`Cleaning up SSE session ${sessionId}`);

  try {
    // Use provided transport or get from session manager
    const sessionTransport = transport || sessionManager.getSession(sessionId);

    if (sessionTransport) {
      logger.info(`Closing transport for session ${sessionId}`);
      await sessionTransport.close();
      logger.info(`Transport cleaned up for session ${sessionId}`);
    } else {
      logger.info(`No transport found for session ${sessionId}`);
    }

    // Remove from session manager
    sessionManager.removeSession(sessionId);

    // Clean up MetaMCP server pool session
    await metaMcpServerPool.cleanupSession(sessionId);
    removeUserContextForSession(sessionId);

    logger.info(`Session ${sessionId} cleanup completed successfully`);
  } catch (error) {
    logger.error(`Error during cleanup of session ${sessionId}:`, error);
    // Even if cleanup fails, remove the session from manager to prevent memory leaks
    sessionManager.removeSession(sessionId);
    logger.info(`Removed orphaned session ${sessionId} due to cleanup error`);
    throw error;
  }
};

sseRouter.get(
  "/:endpoint_name/sse",
  lookupEndpoint,
  authenticateApiKey,
  rateLimitMiddleware,
  async (req, res) => {
    const authReq = req as ApiKeyAuthenticatedRequest;
    const { namespaceUuid, endpointName } = authReq;

    try {
      logIncomingPublicMetamcpHeaders(
        req,
        `public-metamcp SSE GET /${endpointName}/sse`,
      );
      logger.info(
        `New public endpoint SSE connection request for ${endpointName} -> namespace ${namespaceUuid}`,
      );

      const webAppTransport = new SSEServerTransport(
        `/metamcp/${endpointName}/message`,
        res,
      );
      logger.info("Created public endpoint SSE transport");

      const sessionId = webAppTransport.sessionId;
      const { userId, userEmail, userRole } = userHeadersFromRequest(req);

      const userContext = stripUnresolvedUserFields({
        userId,
        userEmail,
        userRole,
        authMethod: authReq.authMethod,
        authenticatedUserId: authReq.oauthUserId || authReq.apiKeyUserId,
      });
      setUserContextForSession(sessionId, userContext);
      setUserContextForNamespace(namespaceUuid, userContext);

      // Get or create MetaMCP server instance from the pool
      const mcpServerInstance = await metaMcpServerPool.getServer(
        sessionId,
        namespaceUuid,
      );
      if (!mcpServerInstance) {
        throw new Error("Failed to get MetaMCP server instance from pool");
      }

      logger.info(
        `Using MetaMCP server instance for public endpoint session ${sessionId}`,
      );

      sessionManager.addSession(sessionId, webAppTransport);

      // Handle cleanup when connection closes
      res.on("close", async () => {
        logger.info(
          `Public endpoint SSE connection closed for session ${sessionId}`,
        );
        await cleanupSession(sessionId);
      });

      await mcpServerInstance.server.connect(webAppTransport);
    } catch (error) {
      logger.error("Error in public endpoint /sse route:", error);
      res.status(500).json(error);
    }
  },
);

sseRouter.post(
  "/:endpoint_name/message",
  lookupEndpoint,
  authenticateApiKey,
  rateLimitMiddleware,
  async (req, res) => {
    const authReq = req as ApiKeyAuthenticatedRequest;
    const { namespaceUuid } = authReq;

    try {
      const sessionId = req.query.sessionId;
      logIncomingPublicMetamcpHeaders(
        req,
        `public-metamcp SSE POST /message sessionId=${String(sessionId ?? "")}`,
      );

      const transport = sessionManager.getSession(
        sessionId as string,
      ) as SSEServerTransport;
      if (!transport) {
        res.status(404).end("Session not found");
        return;
      }

      // LibreChat substitutes {{LIBRECHAT_USER_*}} on POST, not always on SSE GET — refresh context here.
      const incoming = userHeadersFromRequest(req);
      const prev = getUserContextForSession(sessionId as string);
      const merged = stripUnresolvedUserFields({
        userId: incoming.userId ?? prev?.userId,
        userEmail: incoming.userEmail ?? prev?.userEmail,
        userRole: incoming.userRole ?? prev?.userRole,
        authMethod: authReq.authMethod ?? prev?.authMethod,
        authenticatedUserId:
          authReq.oauthUserId ||
          authReq.apiKeyUserId ||
          prev?.authenticatedUserId,
      });
      setUserContextForSession(sessionId as string, merged);
      setUserContextForNamespace(namespaceUuid, merged);

      await transport.handlePostMessage(req, res);
    } catch (error) {
      logger.error("Error in public endpoint /message route:", error);
      res.status(500).json(error);
    }
  },
);

// Initialize automatic cleanup timer using session manager
sessionManager.startCleanupTimer(async (sessionId, transport) => {
  await cleanupSession(sessionId, transport);
});

export default sseRouter;
