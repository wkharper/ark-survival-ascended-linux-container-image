#!/usr/bin/env bash
#
# backup-saves.sh - Back up ARK world saves (and config) to a timestamped archive.
#
# If the server is running it triggers a SaveWorld first, so the backup is a
# consistent snapshot. Old backups beyond the retention count are pruned.
#
# Place this file next to your docker-compose.yml and run: ./backup-saves.sh
#
# Optional overrides (environment variables):
#   ASA_CONTAINER               container name                 (default: asa-server-1)
#   ASA_SERVER_DIR              host folder holding the binds  (default: asa-server-1)
#   ASA_BACKUP_DIR              where to write backups         (default: ./backups)
#   ASA_BACKUP_KEEP             how many backups to keep       (default: 10)
#   ASA_BACKUP_INCLUDE_CONFIG   also archive the config folder (default: 1; set 0 for saves only)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONTAINER="${ASA_CONTAINER:-asa-server-1}"
SERVER_DIR="${ASA_SERVER_DIR:-asa-server-1}"
BACKUP_DIR="${ASA_BACKUP_DIR:-$SCRIPT_DIR/backups}"
KEEP="${ASA_BACKUP_KEEP:-10}"
INCLUDE_CONFIG="${ASA_BACKUP_INCLUDE_CONFIG:-1}"

SAVES_DIR="$SCRIPT_DIR/$SERVER_DIR/saves"

if [[ ! -d "$SAVES_DIR" ]]; then
  echo "Error: saves folder not found at $SAVES_DIR" >&2
  echo "Has the server completed its first start yet?" >&2
  exit 1
fi

# Consistent snapshot: ask a running server to flush its world to disk first.
if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Server is running - saving world via RCON before backup..."
  if docker exec "$CONTAINER" asa-ctrl rcon --exec "SaveWorld"; then
    sleep 5
  else
    echo "Warning: SaveWorld failed; backing up the current files on disk anyway." >&2
  fi
fi

mkdir -p "$BACKUP_DIR"
TS="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$BACKUP_DIR/asa-backup-$TS.tar.gz"

# Paths are relative to SCRIPT_DIR so the archive restores cleanly with:
#   tar -xzf asa-backup-XXXX.tar.gz -C /path/to/asa-server
PATHS=("$SERVER_DIR/saves")
if [[ "$INCLUDE_CONFIG" == "1" && -d "$SCRIPT_DIR/$SERVER_DIR/config" ]]; then
  PATHS+=("$SERVER_DIR/config")
fi

echo "Creating $ARCHIVE ..."
# The save files are owned by uid 25000, so a normal user may not be able to
# read them. Try directly first, then fall back to sudo.
if tar -czf "$ARCHIVE" -C "$SCRIPT_DIR" "${PATHS[@]}" 2>/dev/null; then
  :
else
  echo "Could not read all files as $(id -un); retrying with sudo..."
  sudo tar -czf "$ARCHIVE" -C "$SCRIPT_DIR" "${PATHS[@]}"
  sudo chown "$(id -u):$(id -g)" "$ARCHIVE"
fi

SIZE="$(du -h "$ARCHIVE" | cut -f1)"
echo "Backup complete: $ARCHIVE ($SIZE)"

# Prune old backups, keeping the newest $KEEP. Filenames are timestamped and
# contain no spaces, so this listing is safe to parse.
if [[ "$KEEP" -gt 0 ]]; then
  mapfile -t OLD < <(ls -1t "$BACKUP_DIR"/asa-backup-*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))")
  if [[ "${#OLD[@]}" -gt 0 ]]; then
    echo "Pruning ${#OLD[@]} old backup(s) (keeping newest $KEEP):"
    for f in "${OLD[@]}"; do
      echo "  rm $f"
      rm -f "$f"
    done
  fi
fi
