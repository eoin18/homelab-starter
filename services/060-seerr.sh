#!/usr/bin/env bash
# hs-name: Seerr (requests)
# hs-url: http://HOST:5055
# hs-group: Media
source "$HS_ROOT/lib/service.sh"
[ "${HS_DRY_RUN:-0}" = 1 ] || { mkdir -p "$APPDATA/seerr"; chown 1000:1000 "$APPDATA/seerr"; }  # image runs as node (1000)
recreate seerr
docker run -d --name seerr "${HS_COMMON[@]}" \
  -p 5055:5055 \
  -e LOG_LEVEL=info -e PORT=5055 \
  -v "$APPDATA/seerr:/app/config" \
  ghcr.io/seerr-team/seerr:latest
