#!/usr/bin/env bash
# hs-name: Uptime Kuma (is it up?)
# hs-url: http://HOST:3002
# hs-group: Monitoring
# 3002 because the Music bundle's Aurral uses 3001. wire/uptime-kuma.py adds a check for every installed service.
source "$HS_ROOT/lib/service.sh"
recreate uptime-kuma
docker run -d --name uptime-kuma "${HS_COMMON[@]}" \
  -p 3002:3001 \
  -v "$APPDATA/uptime-kuma:/app/data" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  louislam/uptime-kuma:2
