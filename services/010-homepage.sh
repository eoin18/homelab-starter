#!/usr/bin/env bash
# hs-name: Homepage (dashboard)
# hs-url: http://HOST:3000
# hs-group: System
source "$HS_ROOT/lib/service.sh"
recreate homepage
docker run -d --name homepage "${HS_COMMON[@]}" \
  -p 3000:3000 \
  -v "$APPDATA/homepage/config:/app/config" \
  -v "$APPDATA/homepage/images:/app/public/images" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -e HOMEPAGE_ALLOWED_HOSTS='*' \
  -e PUID="$PUID" -e PGID="$PGID" \
  ghcr.io/gethomepage/homepage:latest
