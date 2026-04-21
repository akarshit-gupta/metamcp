import type { IncomingHttpHeaders } from "node:http";

import { normalizeIncomingHeaders } from "./normalize";

const snapshotBySessionId = new Map<string, Record<string, string>>();

export function setPublicSseSnapshotFromRequest(
  sessionId: string,
  headers: IncomingHttpHeaders,
): void {
  snapshotBySessionId.set(sessionId, normalizeIncomingHeaders(headers));
}

export function getPublicSseSnapshot(
  sessionId: string,
): Record<string, string> | undefined {
  return snapshotBySessionId.get(sessionId);
}

export function clearPublicSseSnapshot(sessionId: string): void {
  snapshotBySessionId.delete(sessionId);
}
