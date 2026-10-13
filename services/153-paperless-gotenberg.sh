#!/usr/bin/env bash
# hs-name: Paperless PDF converter
# hs-group: Personal
source "$HS_ROOT/lib/service.sh"
docker network inspect paperless >/dev/null 2>&1 || docker network create paperless >/dev/null
recreate paperless-gotenberg
docker run -d --name paperless-gotenberg "${HS_COMMON[@]}" --network paperless \
  gotenberg/gotenberg:8 gotenberg --chromium-disable-javascript=true --chromium-allow-list='file:///tmp/.*'
