#!/usr/bin/env bash
# hs-name: Jellyfin (watch)
# hs-url: http://HOST:8096
# hs-group: Media
source "$HS_ROOT/lib/service.sh"
GPU_ARGS=(); [ "${GPU:-none}" = yes ] && GPU_ARGS=(--device /dev/dri:/dev/dri --group-add "$(stat -c %g /dev/dri/renderD128 2>/dev/null || echo video)")
[ "${HS_DRY_RUN:-0}" = 1 ] || { mkdir -p "$APPDATA/jellyfin/config" "$APPDATA/jellyfin/cache"; chown -R "$PUID:$PGID" "$APPDATA/jellyfin"; }
recreate jellyfin
docker run -d --name jellyfin "${HS_COMMON[@]}" \
  --user "$PUID:$PGID" "${GPU_ARGS[@]}" \
  -p 8096:8096 -p 7359:7359/udp \
  -v "$APPDATA/jellyfin/config:/config" \
  -v "$APPDATA/jellyfin/cache:/cache" \
  -v "$DATA_MOVIES/library:/media/movies" \
  -v "$DATA_TV/library:/media/tv" \
  jellyfin/jellyfin:latest
