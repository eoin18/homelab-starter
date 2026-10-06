#!/usr/bin/env bash
# Create Portainer's admin account (only possible in the first minutes after a fresh start).
set -euo pipefail
. "$HS_ROOT/lib/common.sh"
marker_done portainer-admin && exit 0
wait_for_http "https://localhost:9443" 120 || { curl -sk -o /dev/null https://localhost:9443 || exit 1; }
for i in $(seq 1 30); do curl -sk -o /dev/null https://localhost:9443/api/system/status && break; sleep 2; done
code=$(curl -sk -o /dev/null -w '%{http_code}' -X POST https://localhost:9443/api/users/admin/init \
  -H 'Content-Type: application/json' -d "{\"Username\":\"$ADMIN_USER\",\"Password\":\"$ADMIN_PASSWORD\"}")
case "$code" in 200|204) marker_set portainer-admin ;; 409) marker_set portainer-admin ;;  # already initialised
  *) echo "portainer admin init returned HTTP $code" >&2; exit 1 ;; esac
