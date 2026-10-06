#!/usr/bin/env bash
# Sourced by services/*.sh. Config + secrets are already exported by install.sh.
set -euo pipefail
if [ "${HS_DRY_RUN:-0}" = 1 ]; then
  docker() { printf '    [dry-run] docker'; printf ' %q' "$@"; echo; }
  recreate() { :; }
else
  recreate() { docker rm -f "$1" >/dev/null 2>&1 || true; }
fi
# Common flags every container gets
HS_COMMON=(--restart unless-stopped --add-host=host.docker.internal:host-gateway -e TZ="$TZ")
