import type { ServerParameters } from "@repo/zod-types";

import { isForwardSseHeadersEnabled } from "./env";
import { mergeSseDownstreamHeaders } from "./merge-sse-downstream";

/** Optional ingress snapshot for child SSE/Streamable HTTP; see `METAMCP_FORWARD_SSE_HEADERS`. */
export type HttpChildMcpConnectOptions = {
  publicIngressHeaders?: Record<string, string>;
};

function getPublicIngress(
  o?: HttpChildMcpConnectOptions,
): Record<string, string> | undefined {
  const h = o?.publicIngressHeaders;
  if (!h || Object.keys(h).length === 0) {
    return undefined;
  }
  return h;
}

/**
 * Resolves `requestInit.headers` for child MCP clients over **SSE** and **Streamable HTTP**.
 * All `METAMCP_FORWARD_SSE_HEADERS` behavior is confined here; upstream can merge by keeping
 * this function as the only extension point in `client.ts`.
 */
export function buildHttpChildMcpRequestHeaders(
  serverParams: ServerParameters,
  connectOptions?: HttpChildMcpConnectOptions,
): Record<string, string> {
  if (isForwardSseHeadersEnabled()) {
    const forward = getPublicIngress(connectOptions);
    if (forward) {
      return mergeSseDownstreamHeaders(forward, serverParams);
    }
  }
  return { ...(serverParams.headers || {}) };
}
