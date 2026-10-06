#!/usr/bin/env bash
# hs-name: Sonarr (TV)
# hs-url: http://HOST:8989
# hs-group: Media
source "$HS_ROOT/lib/service.sh"
arr_config "$APPDATA/sonarr" 8989 "$SONARR_API_KEY"
recreate sonarr
docker run -d --name sonarr "${HS_COMMON[@]}" "${HS_IDS[@]}" \
  -p 8989:8989 \
  -v "$APPDATA/sonarr:/config" \
  "${HS_DATA_MOUNTS[@]}" \
  lscr.io/linuxserver/sonarr:latest
