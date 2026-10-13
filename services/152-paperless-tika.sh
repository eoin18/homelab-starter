#!/usr/bin/env bash
# hs-name: Paperless Office-file reader
# hs-group: Personal
# PINNED to Tika 3.x (the tag Paperless's own compose uses): Tika 4 removed the endpoints Paperless calls. Bump with Paperless.
source "$HS_ROOT/lib/service.sh"
docker network inspect paperless >/dev/null 2>&1 || docker network create paperless >/dev/null
recreate paperless-tika
docker run -d --name paperless-tika "${HS_COMMON[@]}" --network paperless apache/tika:3.3.1.0
