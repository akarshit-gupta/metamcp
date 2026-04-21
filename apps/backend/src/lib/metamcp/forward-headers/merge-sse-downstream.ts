import type { ServerParameters } from "@repo/zod-types";

/**
 * LibreChat / ingress headers first; DB-configured headers override on same key (static secrets).
 * Empty or whitespace-only DB values are skipped so they do not wipe ingress headers (e.g. unset
 * template placeholders for x-user-group-* on the MCP server record).
 * Caller adds Authorization after this merge.
 */
export function mergeSseDownstreamHeaders(
  incoming: Record<string, string>,
  serverParams: ServerParameters,
): Record<string, string> {
  const merged: Record<string, string> = { ...incoming };
  for (const [k, v] of Object.entries(serverParams.headers || {})) {
    if (v === undefined) continue;
    const trimmed = String(v).trim();
    if (trimmed.length === 0) continue;
    merged[k.toLowerCase()] = v;
  }
  return merged;
}
