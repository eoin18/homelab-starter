#!/usr/bin/env bash
# hs-name: Bazarr (subtitles)
# hs-url: http://HOST:6767
# hs-group: Media
source "$HS_ROOT/lib/service.sh"
recreate bazarr
docker run -d --name bazarr "${HS_COMMON[@]}" "${HS_IDS[@]}" \
  -p 6767:6767 \
  -v "$APPDATA/bazarr:/config" \
  "${HS_DATA_MOUNTS[@]}" \
  lscr.io/linuxserver/bazarr:latest
