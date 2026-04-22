/** When `1`, merge LibreChat (ingress) headers into outbound SSE MCP client connections. */
export function isForwardSseHeadersEnabled(): boolean {
  return process.env.METAMCP_FORWARD_SSE_HEADERS === "1";
}

/** When `1`, log incoming public SSE requests and outbound SSE connect headers. */
export function isDebugIncomingHeadersEnabled(): boolean {
  return process.env.METAMCP_DEBUG_INCOMING_HEADERS === "1";
}

/**
 * When `1`, log outbound child MCP connect attempts, resolved URL, and failures (status / hint).
 * Also implied when `METAMCP_DEBUG_INCOMING_HEADERS=1` so a single "full debug" toggle works.
 */
export function isDebugMcpConnectEnabled(): boolean {
  return (
    process.env.METAMCP_DEBUG_MCP_CONNECT === "1" ||
    isDebugIncomingHeadersEnabled()
  );
}
