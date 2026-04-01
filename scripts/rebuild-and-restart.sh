#!/usr/bin/env bash
# Build MetaMCP (dev compose) and start/restart containers.
# Run from repo root: ./scripts/rebuild-and-restart.sh
#
# Uses podman when available (override: DOCKER_CMD=docker).
# Default stack: docker-compose.dev.yml (app + postgres, ports 12008/12009).
#
# Optional env:
#   COMPOSE_FILE  — override compose file (default: docker-compose.dev.yml)
#   DOCKER_CMD    — "docker" or "podman" (default: podman if installed, else docker)

set -euo pipefail

if [ -n "${DOCKER_CMD:-}" ]; then
  COMPOSE_CMD="$DOCKER_CMD"
else
  if command -v podman &>/dev/null; then
    COMPOSE_CMD="podman"
  elif command -v docker &>/dev/null; then
    COMPOSE_CMD="docker"
  else
    echo "Neither podman nor docker found. Install one or set DOCKER_CMD." >&2
    exit 1
  fi
fi
COMPOSE="$COMPOSE_CMD compose"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.dev.yml}"
COMPOSE_PATH="$ROOT_DIR/$COMPOSE_FILE"

if [ ! -f "$COMPOSE_PATH" ]; then
  echo "Compose file not found: $COMPOSE_PATH" >&2
  exit 1
fi

echo "=== Building and restarting MetaMCP (using $COMPOSE_CMD, $COMPOSE_FILE) ==="
cd "$ROOT_DIR"
$COMPOSE -f "$COMPOSE_PATH" --project-directory "$ROOT_DIR" build
$COMPOSE -f "$COMPOSE_PATH" --project-directory "$ROOT_DIR" up -d

echo "Done. MetaMCP dev: frontend http://localhost:12008, backend http://localhost:12009"
echo "Postgres (if using dev compose): host localhost, port \${POSTGRES_EXTERNAL_PORT:-9433}"
