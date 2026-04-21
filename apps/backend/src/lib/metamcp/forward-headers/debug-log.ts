import type { IncomingHttpHeaders } from "node:http";

import logger from "@/utils/logger";

import { isDebugIncomingHeadersEnabled } from "./env";
import { normalizeIncomingHeaders } from "./normalize";

function logHeaderBlock(title: string, headers: Record<string, string>): void {
  const names = Object.keys(headers).sort();
  logger.info(
    `[MetaMCP DEBUG incoming headers] ${title} (${names.length} header names)`,
  );
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
  logHeaderBlock(`SSE GET /${endpointName}/sse`, h);
}

export function debugLogIncomingSsePost(
  endpointName: string,
  sessionId: string,
  headers: IncomingHttpHeaders,
): void {
  if (!isDebugIncomingHeadersEnabled()) return;
  const h = normalizeIncomingHeaders(headers);
  logHeaderBlock(
    `SSE POST /${endpointName}/message sessionId=${sessionId}`,
    h,
  );
}

export function debugLogDownstreamSseConnect(
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
  logHeaderBlock(
    `[MetaMCP DEBUG downstream headers] SSE connect → ${serverName} (${host})`,
    headers,
  );
}
