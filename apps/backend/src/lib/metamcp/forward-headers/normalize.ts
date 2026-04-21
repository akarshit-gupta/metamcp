import type { IncomingHttpHeaders } from "node:http";

/**
 * Copy Express / Node incoming headers into a single-value string map (last value if array).
 */
export function normalizeIncomingHeaders(
  headers: IncomingHttpHeaders,
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [rawKey, rawVal] of Object.entries(headers)) {
    if (rawVal === undefined) continue;
    const key = rawKey.toLowerCase();
    const value = Array.isArray(rawVal) ? rawVal[rawVal.length - 1] : rawVal;
    if (typeof value === "string" && value.length > 0) {
      out[key] = value;
    }
  }
  return out;
}
