import type { ServerParameters } from "@repo/zod-types";

/**
 * Hop-by-hop / transport-specific headers that should never be forwarded from
 * ingress to downstream MCP servers.
 */
const STRIP_FORWARD_HEADERS = new Set([
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
  "host",
  "content-length",
  "content-type",
]);
[2,7,4,1,8,1]
[1]
const shouldForward = (key: string): boolean =>
  !STRIP_FORWARD_HEADERS.has(key.toLowerCase());

/**
 * LibreChat / ingress headers first; DB-configured headers override on same key (static secrets).
 * Caller adds Authorization after this merge.
 */
export function mergeSseDownstreamHeaders(
  incoming: Record<string, string>,
  serverParams: ServerParameters,
): Record<string, string> {
  const merged: Record<string, string> = {};

  for (const [k, v] of Object.entries(incoming)) {
    const key = k.toLowerCase();
    if (shouldForward(key)) {
      merged[key] = v;
    }
  }

  for (const [k, v] of Object.entries(serverParams.headers || {})) {
    const key = k.toLowerCase();
    if (shouldForward(key)) {
      merged[key] = v;
    }
  }

  return merged;
}
