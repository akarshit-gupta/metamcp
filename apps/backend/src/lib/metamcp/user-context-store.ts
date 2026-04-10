export interface MetaMcpUserContext {
  userId?: string;
  userEmail?: string;
  userRole?: string;
  /** From X-User-Groups (e.g. comma-separated group ids from LibreChat). */
  userGroups?: string;
  authMethod?: "api_key" | "oauth";
  authenticatedUserId?: string;
}

const sessionUserContext = new Map<string, MetaMcpUserContext>();
const namespaceUserContext = new Map<string, MetaMcpUserContext>();

export function setUserContextForSession(
  sessionId: string,
  context: MetaMcpUserContext,
): void {
  sessionUserContext.set(sessionId, context);
}

export function getUserContextForSession(
  sessionId: string,
): MetaMcpUserContext | undefined {
  return sessionUserContext.get(sessionId);
}

export function setUserContextForNamespace(
  namespaceUuid: string,
  context: MetaMcpUserContext,
): void {
  namespaceUserContext.set(namespaceUuid, context);
}

export function getUserContextForNamespace(
  namespaceUuid: string,
): MetaMcpUserContext | undefined {
  return namespaceUserContext.get(namespaceUuid);
}

export function removeUserContextForSession(sessionId: string): void {
  sessionUserContext.delete(sessionId);
}
