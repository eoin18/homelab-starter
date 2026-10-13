#!/usr/bin/env bash
# hs-name: Paperless queue
# hs-group: Personal
source "$HS_ROOT/lib/service.sh"
docker network inspect paperless >/dev/null 2>&1 || docker network create paperless >/dev/null
recreate paperless-redis
docker run -d --name paperless-redis "${HS_COMMON[@]}" --network paperless redis:8-alpine
