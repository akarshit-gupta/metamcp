/**
 * When `1`, merge LibreChat (ingress) headers into outbound child MCP **SSE** and
 * **Streamable HTTP** client connections.
 */
export function isForwardSseHeadersEnabled(): boolean {
  return process.env.METAMCP_FORWARD_SSE_HEADERS === "1";
}

/**
 * When `1`, log (via app logger) incoming public `/sse` and `/message` headers, and
 * merged outbound child MCP headers. Set `LOG_LEVEL=info` (or `all`) to see them in pod logs.
 */
export function isDebugIncomingHeadersEnabled(): boolean {
  return process.env.METAMCP_DEBUG_INCOMING_HEADERS === "1";
}
