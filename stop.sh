#!/usr/bin/env bash
#
# stop.sh - Gracefully stop the ARK: Survival Ascended server.
#
# Saves the world via RCON first so you don't lose recent progress,
# then stops the container (containers and volumes are kept; only the
# running process is stopped, so ./start.sh brings it right back).
#
# Place this file next to your docker-compose.yml and run: ./stop.sh
#
# Optional overrides (environment variables):
#   ASA_CONTAINER              container name                 (default: asa-server-1)
#   ASA_COMPOSE_FILE           compose file                   (default: docker-compose.yml)
#   ASA_SHUTDOWN_WARN_SECONDS  warn players, then wait N secs (default: 0 = no warning)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONTAINER="${ASA_CONTAINER:-asa-server-1}"
COMPOSE_FILE="${ASA_COMPOSE_FILE:-docker-compose.yml}"
WARN_SECONDS="${ASA_SHUTDOWN_WARN_SECONDS:-0}"

if docker compose version >/dev/null 2>&1; then
  DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  DC=(docker-compose)
else
  echo "Error: neither 'docker compose' nor 'docker-compose' is available." >&2
  exit 1
fi

rcon() {
  docker exec "$CONTAINER" asa-ctrl rcon --exec "$1"
}

# Only try to talk to the server if it's actually running.
if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  if [[ "$WARN_SECONDS" -gt 0 ]]; then
    echo "Warning players: server stops in ${WARN_SECONDS}s..."
    rcon "ServerChat Server is shutting down in ${WARN_SECONDS} seconds. Disconnect to be safe." || \
      echo "  (could not broadcast warning - continuing)" >&2
    sleep "$WARN_SECONDS"
  fi

  echo "Saving world via RCON..."
  if rcon "SaveWorld"; then
    echo "World saved."
    # Give the game a moment to flush the save to disk before we stop it.
    sleep 5
  else
    echo "Warning: SaveWorld failed (is RCON / ServerAdminPassword configured?)." >&2
    echo "Stopping anyway - the most recent autosave will be used." >&2
  fi
else
  echo "${CONTAINER} is not running; nothing to save."
fi

echo "Stopping ${CONTAINER}..."
"${DC[@]}" -f "$COMPOSE_FILE" stop

echo "Done. Restart with ./start.sh"
