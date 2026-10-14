#!/usr/bin/env bash
# hs-name: Audiobookshelf (audiobooks & podcasts)
# hs-url: http://HOST:13378
# hs-group: Books
# Audiobooks in $DATA_AUDIOBOOKS, podcasts in $DATA_PODCASTS (new episodes download on their own). Phone apps keep
# listening progress in sync with the web player.
source "$HS_ROOT/lib/service.sh"
if [ "${HS_DRY_RUN:-0}" != 1 ]; then
  mkdir -p "$APPDATA/audiobookshelf"/{config,metadata} "$DATA_AUDIOBOOKS" "$DATA_PODCASTS"
  chown "$PUID:$PGID" "$APPDATA/audiobookshelf"/{,config,metadata} "$DATA_AUDIOBOOKS" "$DATA_PODCASTS"
  # Kept on the music drive? Then Navidrome must not index them as music.
  for d in "$DATA_AUDIOBOOKS" "$DATA_PODCASTS"; do
    case "$d/" in "$DATA_MUSIC"/*/) n="${d#"$DATA_MUSIC"/}"; f="$DATA_MUSIC/.ndignore"
      [ -f "$f" ] && ! grep -qx "$n" "$f" && echo "$n" >> "$f" ;; esac
  done
fi
recreate audiobookshelf
docker run -d --name audiobookshelf "${HS_COMMON[@]}" \
  --user "$PUID:$PGID" \
  -p 13378:80 \
  -v "$APPDATA/audiobookshelf/config:/config" \
  -v "$APPDATA/audiobookshelf/metadata:/metadata" \
  -v "$DATA_AUDIOBOOKS:$DATA_AUDIOBOOKS" \
  -v "$DATA_PODCASTS:$DATA_PODCASTS" \
  ghcr.io/advplyr/audiobookshelf:latest
