#!/usr/bin/env bash
# hs-name: Aurral (music discovery)
# hs-url: http://HOST:3001
# hs-group: Music
# Recommendations, trending, new releases; requests go to Lidarr. Same /data mount as Lidarr so paths match.
source "$HS_ROOT/lib/service.sh"
[ "${HS_DRY_RUN:-0}" = 1 ] || { mkdir -p "$APPDATA/aurral"; chown "$PUID:$PGID" "$APPDATA/aurral"; }
recreate aurral
docker run -d --name aurral "${HS_COMMON[@]}" \
  -p 3001:3001 \
  -v "$APPDATA/aurral:/config" \
  "${HS_DATA_MOUNTS[@]}" \
  -e PUID="$PUID" -e PGID="$PGID" \
  ghcr.io/lklynet/aurral:latest
