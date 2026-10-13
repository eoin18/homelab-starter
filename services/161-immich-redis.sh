#!/usr/bin/env bash
# hs-name: Immich queue
# hs-group: Personal
source "$HS_ROOT/lib/service.sh"
docker network inspect immich >/dev/null 2>&1 || docker network create immich >/dev/null
recreate immich-redis
docker run -d --name immich-redis "${HS_COMMON[@]}" --network immich valkey/valkey:9
