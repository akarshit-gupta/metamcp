import type { Request } from "express";

/**
 * Debug: print incoming HTTP headers for public MetaMCP routes (always to stdout;
 * not gated by LOG_LEVEL so you see them in kubectl logs / Docker).
 * Authorization and Cookie values are redacted.
 */
export function logIncomingPublicMetamcpHeaders(
  req: Request,
  context: string,
): void {
  const headers: Record<string, string | string[] | undefined> = {
    ...req.headers,
  };
  if (headers.authorization) {
    headers.authorization = "[redacted]";
  }
  if (headers.cookie) {
    headers.cookie = "[redacted]";
  }
  // eslint-disable-next-line no-console -- intentional debug for header forwarding
  console.log(`[MetaMCP headers] ${context}: ${JSON.stringify(headers)}`);
}
