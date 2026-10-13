#!/usr/bin/env bash
# Uptime Kuma: first-run DB + admin login, ntfy alerts, and a check for every installed service.
# Runs the socket.io setup inside a throwaway Python container, so the host needs nothing extra.
set -eu
. "$HS_ROOT/lib/common.sh"
wait_for_http "http://localhost:3002" 120 || true
curl -s -o /dev/null -X POST http://localhost:3002/setup-database -H 'Content-Type: application/json' -d '{"dbConfig":{"type":"sqlite"}}' || true
# Kuma now restarts into its main server and migrates (~20 s); wait until it no longer redirects to /setup-database
for _ in $(seq 1 90); do
  r=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' http://localhost:3002/ 2>/dev/null || true)
  case "$r" in 30[0-9]*setup-database*|000*|"") sleep 2 ;; *) break ;; esac
done
TARGETS=$(for f in "$HS_ROOT"/services/*.sh; do s=$(basename "$f" .sh); s=${s#*-}
  docker inspect "$s" >/dev/null 2>&1 || continue
  u=$(grep -m1 '^# hs-url:' "$f" | sed 's/^# hs-url: *//'); n=$(grep -m1 '^# hs-name:' "$f" | sed 's/^# hs-name: *//; s/ (.*//')
  printf '%s\t%s\t%s\n' "$s" "${n:-$s}" "${u/HOST/host.docker.internal}"; done)
if docker run --rm -i --network host -e KUMA_USER="$ADMIN_USER" -e KUMA_PASS="$ADMIN_PASSWORD" -e TARGETS="$TARGETS" \
     -v "$HS_ROOT/wire/uptime-kuma-setup.py:/setup.py:ro" python:3.12-slim \
     sh -c 'pip install -q --disable-pip-version-check "python-socketio[client]" websocket-client >/dev/null 2>&1 && python /setup.py'; then
  todo_clear uptime-kuma
else
  todo_add uptime-kuma "Set up Uptime Kuma" "Open <a href=\"http://HOST:3002\">Uptime Kuma</a>, create the admin account, add an <b>ntfy</b> notification (server <code>http://host.docker.internal:8086</code>, topic <code>homelab</code>) and a monitor per app."
fi
