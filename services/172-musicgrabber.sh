#!/usr/bin/env bash
# hs-name: MusicGrabber (songs + playlists)
# hs-url: http://HOST:38274
# hs-group: Music
# Single tracks / playlists / followed artists into $DATA_MUSIC/grabber. Lossless sources are converted to Opus 192k.
source "$HS_ROOT/lib/service.sh"
[ "${HS_DRY_RUN:-0}" = 1 ] || { mkdir -p "$APPDATA/musicgrabber"; chown "$PUID:$PGID" "$APPDATA/musicgrabber"; }
recreate musicgrabber
docker run -d --name musicgrabber "${HS_COMMON[@]}" \
  --shm-size 2048m \
  -p 38274:8080 \
  -v "$DATA_MUSIC/grabber:/music" \
  -v "$APPDATA/musicgrabber:/data" \
  -e MUSIC_DIR=/music -e DB_PATH=/data/music_grabber.db -e PUID="$PUID" -e PGID="$PGID" \
  -e ENABLE_MUSICBRAINZ=true -e DEFAULT_CONVERT_AUDIO=true -e AUDIO_FORMAT=opus -e OPUS_BITRATE=192k -e CONVERT_LOSSLESS_ONLY=true \
  -e NAVIDROME_URL=http://host.docker.internal:4533 -e NAVIDROME_USER="$ADMIN_USER" -e NAVIDROME_PASS="$ADMIN_PASSWORD" \
  -e LIDARR_URL=http://host.docker.internal:8686 -e LIDARR_API_KEY="$LIDARR_API_KEY" \
  g33kphr33k/musicgrabber:latest
