#!/usr/bin/env bash
# hs-name: Navidrome (music streaming)
# hs-url: http://HOST:4533
# hs-group: Music
# Plays everything under $DATA_MUSIC (read-only; downloads/ skipped). Works with any Subsonic phone app.
source "$HS_ROOT/lib/service.sh"
[ "${HS_DRY_RUN:-0}" = 1 ] || { mkdir -p "$APPDATA/navidrome"; chown "$PUID:$PGID" "$APPDATA/navidrome"; }
printf 'lost+found\ndownloads\n' | write_once "$DATA_MUSIC/.ndignore"   # skip these folders
recreate navidrome
docker run -d --name navidrome "${HS_COMMON[@]}" \
  --user "$PUID:$PGID" \
  -p 4533:4533 \
  -v "$APPDATA/navidrome:/data" \
  -v "$DATA_MUSIC:$DATA_MUSIC:ro" \
  -e ND_MUSICFOLDER="$DATA_MUSIC" -e ND_SCANSCHEDULE=1h -e ND_ENABLEINSIGHTSCOLLECTOR=false \
  deluan/navidrome:latest
