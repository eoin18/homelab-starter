#!/usr/bin/env bash
# hs-name: Paperless (documents)
# hs-url: http://HOST:8095
# hs-group: Personal
# Searchable document archive (OCR). Drop files into $APPDATA/paperless/consume (sub-folders become tags).
source "$HS_ROOT/lib/service.sh"
[ "${HS_DRY_RUN:-0}" = 1 ] || { mkdir -p "$APPDATA/paperless"/{data,media,export,consume}; chown "$PUID:$PGID" "$APPDATA/paperless"/{data,media,export,consume}; }
docker network inspect paperless >/dev/null 2>&1 || docker network create paperless >/dev/null
recreate paperless
docker run -d --name paperless "${HS_COMMON[@]}" --network paperless \
  -p 8095:8000 \
  -v "$APPDATA/paperless/data:/usr/src/paperless/data" \
  -v "$APPDATA/paperless/media:/usr/src/paperless/media" \
  -v "$APPDATA/paperless/export:/usr/src/paperless/export" \
  -v "$APPDATA/paperless/consume:/usr/src/paperless/consume" \
  -e PAPERLESS_URL="http://$HOST_IP:8095" \
  -e PAPERLESS_REDIS=redis://paperless-redis:6379 \
  -e PAPERLESS_DBHOST=paperless-db -e PAPERLESS_DBPASS="$PAPERLESS_DB_PASSWORD" \
  -e PAPERLESS_SECRET_KEY="$PAPERLESS_SECRET_KEY" \
  -e PAPERLESS_ADMIN_USER="$ADMIN_USER" -e PAPERLESS_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  -e PAPERLESS_TIME_ZONE="$TZ" -e PAPERLESS_OCR_LANGUAGE="${PAPERLESS_OCR_LANGUAGE:-eng}" \
  -e PAPERLESS_TIKA_ENABLED=1 -e PAPERLESS_TIKA_ENDPOINT=http://paperless-tika:9998 \
  -e PAPERLESS_TIKA_GOTENBERG_ENDPOINT=http://paperless-gotenberg:3000 \
  -e PAPERLESS_CONSUMER_RECURSIVE=true -e PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS=true -e PAPERLESS_CONSUMER_DELETE_DUPLICATES=true \
  -e PAPERLESS_FILENAME_FORMAT='{{ created_year }}/{{ correspondent }}/{{ title }}' \
  -e PAPERLESS_TASK_WORKERS=1 -e PAPERLESS_THREADS_PER_WORKER=2 \
  -e USERMAP_UID="$PUID" -e USERMAP_GID="$PGID" \
  ghcr.io/paperless-ngx/paperless-ngx:latest
