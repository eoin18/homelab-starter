#!/usr/bin/env bash
# hs-name: Lidarr (albums)
# hs-url: http://HOST:8686
# hs-group: Music
# Lossless profile; COPIES into the library (not hardlinks) so it can write proper tags without touching the seeding copy.
source "$HS_ROOT/lib/service.sh"
arr_config "$APPDATA/lidarr" 8686 "$LIDARR_API_KEY"
recreate lidarr
docker run -d --name lidarr "${HS_COMMON[@]}" "${HS_IDS[@]}" \
  -p 8686:8686 \
  -v "$APPDATA/lidarr:/config" \
  "${HS_DATA_MOUNTS[@]}" \
  lscr.io/linuxserver/lidarr:latest
