#!/usr/bin/env bash
# Daily backup of the critical, NON-git runtime state for the Zlatibor stack.
#
# What git does NOT hold (and what you'd have to rebuild by hand if the disk
# dies): the Z-Wave network + HA registries/config-entries/auth in .storage, the
# Z-Wave JS driver cache, the driver security keys, and secrets.yaml.
#
# Usage:  zauto-backup.sh [DEST_DIR]      (default DEST below)
#   KEEP=N env var controls how many rotations to retain (default 14).
#
# NOTE: the archive contains SECRETS (security keys, secrets.yaml). It is written
# mode 600 in a root-only dir. For real disaster recovery, copy it OFF this box
# (see the REMOTE_COPY hook near the bottom) — a local copy only survives edits
# and corruption, not a disk failure.
set -euo pipefail

DEST="${1:-/home/pi/zauto-backups}"
KEEP="${KEEP:-14}"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="${DEST}/zauto-state-${TS}.tar.gz"

install -d -m 700 "$DEST"

# Paths are relative to / so the archive is portable. Missing paths are skipped.
paths=(
  home/homeassistant/.homeassistant/.storage
  home/homeassistant/.homeassistant/secrets.yaml
  var/lib/zwave-js/cache
  etc/zwave-js/config.js
)
present=()
for p in "${paths[@]}"; do [ -e "/$p" ] && present+=("$p"); done

tar -czf "$OUT" -C / "${present[@]}"
chmod 600 "$OUT"

# Rotate: keep the newest $KEEP archives.
mapfile -t old < <(ls -1t "${DEST}"/zauto-state-*.tar.gz 2>/dev/null | tail -n +$((KEEP+1)))
[ ${#old[@]} -gt 0 ] && rm -f "${old[@]}"

echo "backup -> $OUT ($(du -h "$OUT" | cut -f1)); retained $(ls -1 "${DEST}"/zauto-state-*.tar.gz | wc -l)"

# --- Optional off-device copy (uncomment + configure for real DR) ------------
# rsync -a "$OUT" user@nas:/backups/zlatibor/     || echo "WARN: remote copy failed"
# rclone copy "$OUT" remote:zlatibor-backups/     || echo "WARN: rclone failed"
