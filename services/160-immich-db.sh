#!/usr/bin/env bash
# hs-name: Immich database
# hs-group: Personal
# Immich's Postgres build (vectorchord). Digest-pinned as in Immich's official compose: Dockhand skips it; bump with Immich.
source "$HS_ROOT/lib/service.sh"
docker network inspect immich >/dev/null 2>&1 || docker network create immich >/dev/null
recreate immich-db
docker run -d --name immich-db "${HS_COMMON[@]}" --network immich \
  --shm-size 128m \
  -v "$APPDATA/immich-db:/var/lib/postgresql/data" \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD="$IMMICH_DB_PASSWORD" -e POSTGRES_DB=immich -e POSTGRES_INITDB_ARGS=--data-checksums \
  ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23
