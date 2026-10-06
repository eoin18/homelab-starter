#!/usr/bin/env bash
# hs-name: Prowlarr (indexers)
# hs-url: http://HOST:9696
# hs-group: Downloads
source "$HS_ROOT/lib/service.sh"
arr_config "$APPDATA/prowlarr" 9696 "$PROWLARR_API_KEY"
recreate prowlarr
docker run -d --name prowlarr "${HS_COMMON[@]}" "${HS_IDS[@]}" \
  -p 9696:9696 \
  -v "$APPDATA/prowlarr:/config" \
  lscr.io/linuxserver/prowlarr:latest
