import type { Request } from "express";

function isHeaderDebugEnabled(): boolean {
  const value = process.env.METAMCP_DEBUG_INCOMING_HEADERS?.toLowerCase();
  return value === "1" || value === "true" || value === "yes";
}

function redactHeaderValue(
  key: string,
  value: string | string[] | undefined,
): string {
  const normalized = key.toLowerCase();
  if (
    normalized === "authorization" ||
    normalized === "proxy-authorization" ||
    normalized === "cookie" ||
    normalized === "set-cookie" ||
    normalized === "x-api-key"
  ) {
    return "[redacted]";
  }
  if (value === undefined) return "";
  return Array.isArray(value) ? value.join(", ") : value;
}

function logHeadersBlock(
  title: string,
  headers: Record<string, string | string[] | undefined>,
): void {
  if (!isHeaderDebugEnabled()) {
    return;
  }

  const keys = Object.keys(headers).sort((a, b) =>
    a.localeCompare(b, undefined, { sensitivity: "base" }),
  );

  // eslint-disable-next-line no-console -- explicit debug output bypassing LOG_LEVEL
  console.log(`${title} (${keys.length} header names)`);
  for (const key of keys) {
    // eslint-disable-next-line no-console -- explicit debug output bypassing LOG_LEVEL
    console.log(`  ${key}: ${redactHeaderValue(key, headers[key])}`);
  }
}

export function logIncomingPublicMetamcpHeaders(
  req: Request,
  context: string,
): void {
  logHeadersBlock(`[MetaMCP DEBUG incoming headers] ${context}`, {
    ...req.headers,
  });
}

export function logForwardedMcpHeaders(
  context: string,
  headers: Record<string, string>,
): void {
  logHeadersBlock(`[MetaMCP DEBUG forwarded headers] ${context}`, headers);
}
