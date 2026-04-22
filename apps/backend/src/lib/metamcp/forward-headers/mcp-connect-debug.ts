import type { ServerParameters } from "@repo/zod-types";

import logger from "@/utils/logger";

import { isDebugMcpConnectEnabled } from "./env";

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return `${error.name}: ${error.message}`;
  }
  return String(error);
}

function getHttpishCode(error: unknown): number | undefined {
  if (error && typeof error === "object" && "code" in error) {
    const c = (error as { code?: unknown }).code;
    if (typeof c === "number") return c;
  }
  return undefined;
}

/**
 * Log before `Client.connect` for any child MCP (downstream) transport.
 * Pass `resolvedUrl` = URL after e.g. `transformDockerUrl` (SSE / Streamable HTTP only).
 * Uses `console.log` so attempt lines appear when `LOG_LEVEL=errors-only`.
 */
export function debugLogMcpConnectAttempt(args: {
  serverParams: ServerParameters;
  resolvedUrl?: string;
  transportKind: "SSE" | "STREAMABLE_HTTP" | "STDIO";
  hasIngressForward: boolean;
}): void {
  if (!isDebugMcpConnectEnabled()) {
    return;
  }
  const { serverParams, resolvedUrl, transportKind, hasIngressForward } = args;
  const p = serverParams;
  if (transportKind === "STDIO") {
    console.log(
      `[MetaMCP DEBUG MCP connect] attempt name="${p.name}" uuid=${p.uuid} type=STDIO ` +
        `command=${p.command || ""} args=${(p.args || []).join(" ")}`,
    );
    return;
  }
  console.log(
    `[MetaMCP DEBUG MCP connect] attempt name="${p.name}" uuid=${p.uuid} ` +
      `type=${transportKind} url=${resolvedUrl || p.url || "missing"} ` +
      `ingressForward=${hasIngressForward}`,
  );
}

/**
 * After a failed `Client.connect` to a child MCP. Includes 404 / DNS hints.
 */
export function debugLogMcpConnectFailure(args: {
  serverParams: ServerParameters;
  resolvedUrl?: string;
  transportKind: "SSE" | "STREAMABLE_HTTP" | "STDIO";
  error: unknown;
  attempt: number;
  maxAttempts: number;
}): void {
  const {
    serverParams: p,
    resolvedUrl,
    transportKind,
    error,
    attempt,
    maxAttempts,
  } = args;
  const message = getErrorMessage(error);
  const code = getHttpishCode(error);
  const url = resolvedUrl || p.url || "n/a";

  let hint = "";
  if (isDebugMcpConnectEnabled() && code === 404) {
    hint =
      " — hint: 404 = wrong URL path or not exposed at that route (check MCP server URL in DB, Service/Ingress, trailing slash)";
  } else if (isDebugMcpConnectEnabled() && (code === 401 || code === 403)) {
    hint = " — hint: check bearer/headers in MetaMCP server config";
  }

  logger.error(
    `[MetaMCP][client] child MCP connect failed: "${p.name}" (${p.uuid}) ` +
      `attempt ${attempt}/${maxAttempts} ` +
      `${transportKind} url=${url} ` +
      `${code !== undefined ? `code=${code} ` : ""}— ${message}${hint}`,
  );
}
