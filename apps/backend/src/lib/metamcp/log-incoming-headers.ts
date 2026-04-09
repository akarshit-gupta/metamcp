import type { Request } from "express";

function incomingHeadersDebugEnabled(): boolean {
  const v = process.env.METAMCP_DEBUG_INCOMING_HEADERS?.toLowerCase();
  return v === "1" || v === "true" || v === "yes";
}

/**
 * When `METAMCP_DEBUG_INCOMING_HEADERS` is `1`/`true`/`yes`, prints all incoming
 * headers to stdout (so they appear in pod logs even if `LOG_LEVEL=errors-only`).
 * Authorization, Cookie, and X-API-Key values are redacted.
 */
export function logIncomingPublicMetamcpHeaders(
  req: Request,
  context: string,
): void {
  if (!incomingHeadersDebugEnabled()) {
    return;
  }

  const headers: Record<string, string | string[] | undefined> = {
    ...req.headers,
  };
  if (headers.authorization) {
    headers.authorization = "[redacted]";
  }
  if (headers.cookie) {
    headers.cookie = "[redacted]";
  }
  if (headers["x-api-key"]) {
    headers["x-api-key"] = "[redacted]";
  }

  // eslint-disable-next-line no-console -- intentional: bypass LOG_LEVEL for header troubleshooting
  console.log(
    `[MetaMCP DEBUG incoming headers] ${context}: ${JSON.stringify(headers)}`,
  );
}
