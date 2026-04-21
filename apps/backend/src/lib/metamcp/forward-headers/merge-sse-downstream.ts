import type { ServerParameters } from "@repo/zod-types";

/**
 * LibreChat / ingress headers first; DB-configured headers override on same key (static secrets).
 * Caller adds Authorization after this merge.
 */
export function mergeSseDownstreamHeaders(
  incoming: Record<string, string>,
  serverParams: ServerParameters,
): Record<string, string> {
  const merged: Record<string, string> = { ...incoming };
  for (const [k, v] of Object.entries(serverParams.headers || {})) {
    merged[k.toLowerCase()] = v;
  }
  return merged;
}
