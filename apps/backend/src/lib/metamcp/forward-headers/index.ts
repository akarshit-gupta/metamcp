export { isForwardSseHeadersEnabled, isDebugIncomingHeadersEnabled } from "./env";
export { normalizeIncomingHeaders } from "./normalize";
export {
  setPublicSseSnapshotFromRequest,
  getPublicSseSnapshot,
  clearPublicSseSnapshot,
} from "./store";
export { mergeSseDownstreamHeaders } from "./merge-sse-downstream";
export {
  debugLogIncomingSseGet,
  debugLogIncomingSsePost,
  debugLogDownstreamSseConnect,
} from "./debug-log";

import type { IncomingHttpHeaders } from "node:http";

import type { ServerParameters } from "@repo/zod-types";

import { isForwardSseHeadersEnabled } from "./env";
import {
  debugLogIncomingSseGet,
  debugLogIncomingSsePost,
} from "./debug-log";
import {
  clearPublicSseSnapshot,
  getPublicSseSnapshot,
  setPublicSseSnapshotFromRequest,
} from "./store";

/** Public SSE GET: snapshot headers for downstream SSE merges + optional debug. */
export function onPublicSseGet(
  sessionId: string,
  endpointName: string,
  headers: IncomingHttpHeaders,
): void {
  debugLogIncomingSseGet(endpointName, headers);
  if (!isForwardSseHeadersEnabled()) return;
  setPublicSseSnapshotFromRequest(sessionId, headers);
}

/** Public SSE POST /message: optional debug only. */
export function onPublicSseMessage(
  sessionId: string,
  endpointName: string,
  headers: IncomingHttpHeaders,
): void {
  debugLogIncomingSsePost(endpointName, sessionId, headers);
}

export function clearPublicForwardHeadersSession(sessionId: string): void {
  clearPublicSseSnapshot(sessionId);
}

/** Whether idle pool must be skipped for this backend (SSE + forward mode). */
export function shouldBypassSseIdlePool(serverParams: ServerParameters): boolean {
  return isForwardSseHeadersEnabled() && serverParams.type === "SSE";
}

export function getSseForwardSnapshotForSession(
  sessionId: string,
): Record<string, string> | undefined {
  if (!isForwardSseHeadersEnabled()) return undefined;
  const snap = getPublicSseSnapshot(sessionId);
  if (!snap || Object.keys(snap).length === 0) return undefined;
  return snap;
}
