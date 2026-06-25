#!/usr/bin/env bash
#
# start.sh - Start the ARK: Survival Ascended server.
#
# Place this file next to your docker-compose.yml and run: ./start.sh
# Follow the logs as well with:                             ./start.sh --logs
#
# Optional overrides (environment variables):
#   ASA_CONTAINER       container name      (default: asa-server-1)
#   ASA_COMPOSE_FILE    compose file        (default: docker-compose.yml)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONTAINER="${ASA_CONTAINER:-asa-server-1}"
COMPOSE_FILE="${ASA_COMPOSE_FILE:-docker-compose.yml}"

# Pick whichever compose syntax is installed.
if docker compose version >/dev/null 2>&1; then
  DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  DC=(docker-compose)
else
  echo "Error: neither 'docker compose' nor 'docker-compose' is available." >&2
  exit 1
fi

echo "Starting ${CONTAINER}..."
"${DC[@]}" -f "$COMPOSE_FILE" up -d

echo
echo "Server is starting. First launch downloads Steam, Proton and the game files,"
echo "so it can take several minutes before it is reachable."
echo "Watch progress with:  docker logs -f ${CONTAINER}"

if [[ "${1:-}" == "-l" || "${1:-}" == "--logs" ]]; then
  echo
  echo "Following logs (Ctrl+C to stop watching - this does NOT stop the server):"
  exec docker logs -f "$CONTAINER"
fi
