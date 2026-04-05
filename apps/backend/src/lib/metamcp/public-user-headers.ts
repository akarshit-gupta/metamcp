import type { Request } from "express";

import type { MetaMcpUserContext } from "./user-context-store";

const getHeaderString = (
  value: string | string[] | undefined,
): string | undefined => {
  if (!value) return undefined;
  return Array.isArray(value) ? value[0] : value;
};

/** LibreChat may send literal `{{LIBRECHAT_USER_*}}` on SSE GET before substitution. */
function isUnresolvedLibreChatPlaceholder(value: string | undefined): boolean {
  if (!value) return false;
  return value.includes("{{") && value.includes("}}");
}

export function userHeadersFromRequest(req: Request): {
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

export function stripUnresolvedUserFields(
  ctx: MetaMcpUserContext,
): MetaMcpUserContext {
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
