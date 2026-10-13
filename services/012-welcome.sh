#!/usr/bin/env bash
# hs-name: Finish setup (welcome page)
# hs-url: http://HOST:3003
# hs-group: System
# Serves the installer's "Finish setup" page (remaining manual steps + links). busybox httpd, ~1 MB RAM.
source "$HS_ROOT/lib/service.sh"
[ "${HS_DRY_RUN:-0}" = 1 ] || mkdir -p "$APPDATA/welcome"
recreate welcome
docker run -d --name welcome "${HS_COMMON[@]}" \
  -p 3003:80 \
  -v "$APPDATA/welcome:/www:ro" \
  busybox:stable httpd -f -p 80 -h /www
