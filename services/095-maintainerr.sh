#!/usr/bin/env bash
# hs-name: Maintainerr (library clean-up)
# hs-url: http://HOST:6246
# hs-group: Media
# Rules that remove watched/old media so the disk doesn't fill up.
source "$HS_ROOT/lib/service.sh"
[ "${HS_DRY_RUN:-0}" = 1 ] || { mkdir -p "$APPDATA/maintainerr"; chown -R "$PUID:$PGID" "$APPDATA/maintainerr"; }
recreate maintainerr
docker run -d --name maintainerr "${HS_COMMON[@]}" \
  --user "$PUID:$PGID" \
  -p 6246:6246 \
  -v "$APPDATA/maintainerr:/opt/data" \
  ghcr.io/maintainerr/maintainerr:latest
