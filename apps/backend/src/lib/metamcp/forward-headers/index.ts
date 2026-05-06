export {
  isForwardSseHeadersEnabled,
  isDebugIncomingHeadersEnabled,
} from "./env";
export { normalizeIncomingHeaders } from "./normalize";
export {
  setPublicSseSnapshotFromRequest,
  mergePublicSseSnapshotFromRequest,
  getPublicSseSnapshot,
  clearPublicSseSnapshot,
} from "./store";
export { mergeSseDownstreamHeaders } from "./merge-sse-downstream";
export {
  buildHttpChildMcpRequestHeaders,
  type HttpChildMcpConnectOptions,
} from "./http-child-headers";
export {
  debugLogIncomingSseGet,
  debugLogIncomingSsePost,
  debugLogDownstreamMcpConnect,
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
  mergePublicSseSnapshotFromRequest,
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

/** Public SSE POST /message: debug + optional merge of headers into the forward snapshot. */
export function onPublicSseMessage(
  sessionId: string,
  endpointName: string,
  headers: IncomingHttpHeaders,
): void {
  debugLogIncomingSsePost(endpointName, sessionId, headers);
  if (!isForwardSseHeadersEnabled()) return;
  mergePublicSseSnapshotFromRequest(sessionId, headers);
}

export function clearPublicForwardHeadersSession(sessionId: string): void {
  clearPublicSseSnapshot(sessionId);
}

/**
 * When ingress forwarding is on, skip idle reuse for any HTTP child transport that
 * carries the merged ingress headers (SSE and Streamable HTTP), so connections are
 * not shared across user sessions.
 */
export function shouldBypassIdleForIngressForward(
  serverParams: ServerParameters,
): boolean {
  if (!isForwardSseHeadersEnabled()) return false;
  const t = serverParams.type;
  return t === "SSE" || t === "STREAMABLE_HTTP";
}

export function getSseForwardSnapshotForSession(
  sessionId: string,
): Record<string, string> | undefined {
  if (!isForwardSseHeadersEnabled()) return undefined;
  const snap = getPublicSseSnapshot(sessionId);
  if (!snap || Object.keys(snap).length === 0) return undefined;
  return snap;
}
