#!/usr/bin/env bash
# hs-name: Radarr (Movies)
# hs-url: http://HOST:7878
# hs-group: Media
source "$HS_ROOT/lib/service.sh"
arr_config "$APPDATA/radarr" 7878 "$RADARR_API_KEY"
recreate radarr
docker run -d --name radarr "${HS_COMMON[@]}" "${HS_IDS[@]}" \
  -p 7878:7878 \
  -v "$APPDATA/radarr:/config" \
  "${HS_DATA_MOUNTS[@]}" \
  lscr.io/linuxserver/radarr:latest
