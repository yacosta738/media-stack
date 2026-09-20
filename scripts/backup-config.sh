#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_ROOT="${CONFIG_ROOT:?CONFIG_ROOT must point to the host config directory}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="${BACKUP_DIR}/media-config-${STAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"
tar --exclude='*/logs' --exclude='*/MediaCover' --exclude='*/Sentry' -czf "$ARCHIVE" -C "$CONFIG_ROOT" sonarr radarr prowlarr bazarr qbittorrent
printf 'Created %s\n' "$ARCHIVE"
