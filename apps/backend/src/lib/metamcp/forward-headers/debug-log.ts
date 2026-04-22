import type { IncomingHttpHeaders } from "node:http";

import logger from "@/utils/logger";

import { isDebugIncomingHeadersEnabled } from "./env";
import { normalizeIncomingHeaders } from "./normalize";

function logLines(firstLine: string, headers: Record<string, string>): void {
  const names = Object.keys(headers).sort();
  logger.info(`${firstLine} (${names.length} header names)`);
  for (const name of names) {
    logger.info(`  ${name}: ${headers[name]}`);
  }
}

export function debugLogIncomingSseGet(
  endpointName: string,
  headers: IncomingHttpHeaders,
): void {
  if (!isDebugIncomingHeadersEnabled()) return;
  const h = normalizeIncomingHeaders(headers);
  logLines(
    `[MetaMCP DEBUG incoming] SSE GET /${endpointName}/sse`,
    h,
  );
}

export function debugLogIncomingSsePost(
  endpointName: string,
  sessionId: string,
  headers: IncomingHttpHeaders,
): void {
  if (!isDebugIncomingHeadersEnabled()) return;
  const h = normalizeIncomingHeaders(headers);
  logLines(
    `[MetaMCP DEBUG incoming] SSE POST /${endpointName}/message sessionId=${sessionId}`,
    h,
  );
}

export function debugLogDownstreamMcpConnect(
  transportLabel: "SSE" | "Streamable HTTP",
  serverName: string,
  url: string,
  headers: Record<string, string>,
): void {
  if (!isDebugIncomingHeadersEnabled()) return;
  let host = url;
  try {
    host = new URL(url).host;
  } catch {
    /* keep raw */
  }
  logLines(
    `[MetaMCP DEBUG downstream] ${transportLabel} connect → ${serverName} (${host})`,
    headers,
  );
}
