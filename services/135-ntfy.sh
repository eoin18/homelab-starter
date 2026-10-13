#!/usr/bin/env bash
# hs-name: ntfy (push notifications)
# hs-url: http://HOST:8086
# hs-group: Monitoring
# Alerts from Uptime Kuma, Beszel and Dockhand go to topic "homelab"; subscribe in the ntfy phone app.
# Open on the home network / tailnet only (no auth); add auth in server.yml before exposing it to the internet.
source "$HS_ROOT/lib/service.sh"
write_once "$APPDATA/ntfy/config/server.yml" <<YML
base-url: "http://${HOST_IP}:8086"
listen-http: ":80"
cache-file: "/var/cache/ntfy/cache.db"
cache-duration: "72h"
attachment-cache-dir: "/var/cache/ntfy/attachments"
upstream-base-url: "https://ntfy.sh"
YML
[ "${HS_DRY_RUN:-0}" = 1 ] || { mkdir -p "$APPDATA/ntfy/cache"; chown -R "$PUID:$PGID" "$APPDATA/ntfy"; }
recreate ntfy
docker run -d --name ntfy "${HS_COMMON[@]}" \
  --user "$PUID:$PGID" \
  -p 8086:80 \
  -v "$APPDATA/ntfy/config:/etc/ntfy" \
  -v "$APPDATA/ntfy/cache:/var/cache/ntfy" \
  binwiederhier/ntfy:latest serve
