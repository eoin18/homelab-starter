#!/usr/bin/env bash
# Tailscale: without an auth key, put the login link on the Finish-setup page.
set -eu
. "$HS_ROOT/lib/common.sh"
for _ in $(seq 1 20); do st=$(docker exec tailscale tailscale status 2>&1 || true); case "$st" in *login.tailscale.com*|*100.*) break ;; esac; sleep 3; done
url=$(echo "$st" | grep -o 'https://login.tailscale.com/[^ ]*' | head -1 || true)
if [ -z "$url" ]; then url=$(docker logs tailscale 2>&1 | grep -o 'https://login.tailscale.com/[^ ]*' | tail -1 || true); fi
if [ -n "$url" ]; then
  todo_add tailscale "Connect this server to Tailscale" "Open <a href=\"$url\">this login link</a> and sign in to add the server to your tailnet. Then install Tailscale on your phone/laptop with the same account: every app is reachable at <code>http://$(hostname):PORT</code> from anywhere. (If the link has expired: <code>sudo docker restart tailscale</code> and re-run the installer.)"
  ok "tailscale: login link on the Finish-setup page"
else
  todo_clear tailscale; ok "tailscale: connected"
fi
