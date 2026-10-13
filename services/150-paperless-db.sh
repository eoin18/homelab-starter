#!/usr/bin/env bash
# hs-name: Paperless database
# hs-group: Personal
source "$HS_ROOT/lib/service.sh"
docker network inspect paperless >/dev/null 2>&1 || docker network create paperless >/dev/null
recreate paperless-db
docker run -d --name paperless-db "${HS_COMMON[@]}" --network paperless \
  --health-cmd 'pg_isready -U paperless -d paperless' --health-interval 10s --health-timeout 5s --health-retries 5 \
  -v "$APPDATA/paperless-db:/var/lib/postgresql/data" \
  -e POSTGRES_DB=paperless -e POSTGRES_USER=paperless -e POSTGRES_PASSWORD="$PAPERLESS_DB_PASSWORD" \
  postgres:17
