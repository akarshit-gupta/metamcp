import type { IncomingHttpHeaders } from "node:http";

import { normalizeIncomingHeaders } from "./normalize";

const snapshotBySessionId = new Map<string, Record<string, string>>();

export function setPublicSseSnapshotFromRequest(
  sessionId: string,
  headers: IncomingHttpHeaders,
): void {
  snapshotBySessionId.set(sessionId, normalizeIncomingHeaders(headers));
}

/**
 * Merges normalized POST (or any follow-up) headers on top of the GET snapshot
 * for the same session. Later keys override; adds e.g. `mcp-protocol-version` from POST.
 */
export function mergePublicSseSnapshotFromRequest(
  sessionId: string,
  headers: IncomingHttpHeaders,
): void {
  const prev = snapshotBySessionId.get(sessionId) ?? {};
  const incoming = normalizeIncomingHeaders(headers);
  snapshotBySessionId.set(sessionId, { ...prev, ...incoming });
}

export function getPublicSseSnapshot(
  sessionId: string,
): Record<string, string> | undefined {
  return snapshotBySessionId.get(sessionId);
}

export function clearPublicSseSnapshot(sessionId: string): void {
  snapshotBySessionId.delete(sessionId);
}
