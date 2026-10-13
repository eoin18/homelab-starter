#!/usr/bin/env bash
# hs-name: Vaultwarden (passwords)
# hs-url: http://HOST:8094
# hs-group: Personal
# Bitwarden-compatible password manager. The web vault and apps need HTTPS: use the Tailscale or Cloudflare remote
# option (see the Finish-setup page). Sign-ups are off; the admin page (/admin) uses the shared admin password (hashed).
source "$HS_ROOT/lib/service.sh"
VW_HASH=dry-run
[ "${HS_DRY_RUN:-0}" = 1 ] || VW_HASH=$(printf '%s' "$ADMIN_PASSWORD" | docker run --rm -i alpine:3 sh -c 'apk add -q argon2 >/dev/null 2>&1 && argon2 "$(head -c 16 /dev/urandom | base64)" -id -t 3 -m 16 -p 4 -e')
recreate vaultwarden
docker run -d --name vaultwarden "${HS_COMMON[@]}" \
  -p 8094:80 \
  -v "$APPDATA/vaultwarden:/data" \
  -e SIGNUPS_ALLOWED=false \
  -e INVITATIONS_ALLOWED=true \
  -e PASSWORD_HINTS_ALLOWED=false \
  -e SHOW_PASSWORD_HINT=false \
  -e ADMIN_TOKEN="$VW_HASH" \
  vaultwarden/server:latest
