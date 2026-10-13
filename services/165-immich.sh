#!/usr/bin/env bash
# hs-name: Immich (photos)
# hs-url: http://HOST:2283
# hs-group: Personal
# Phone photo backup + Google-Photos-style library. Originals in $DATA_PHOTOS/immich; thumbnails/transcodes in appdata.
source "$HS_ROOT/lib/service.sh"
GPU_ARGS=(); [ "${GPU:-none}" = yes ] && GPU_ARGS=(--device /dev/dri:/dev/dri --group-add "$(stat -c %g /dev/dri/renderD128 2>/dev/null || echo video)")
docker network inspect immich >/dev/null 2>&1 || docker network create immich >/dev/null
recreate immich
docker run -d --name immich "${HS_COMMON[@]}" --network immich "${GPU_ARGS[@]}" \
  -p 2283:2283 \
  -v "$DATA_PHOTOS/immich:/data" \
  -v "$APPDATA/immich/thumbs:/data/thumbs" \
  -v "$APPDATA/immich/encoded-video:/data/encoded-video" \
  -e DB_HOSTNAME=immich-db -e DB_USERNAME=postgres -e DB_PASSWORD="$IMMICH_DB_PASSWORD" -e DB_DATABASE_NAME=immich \
  -e REDIS_HOSTNAME=immich-redis -e IMMICH_MACHINE_LEARNING_URL=http://immich-ml:3003 \
  ghcr.io/immich-app/immich-server:v3
