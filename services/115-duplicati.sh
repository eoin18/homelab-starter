#!/usr/bin/env bash
# hs-name: Duplicati (backups)
# hs-url: http://HOST:8200
# hs-group: System
# Sees the whole machine read-only at /source; writes backups to BACKUP_TARGET (mounted at /backups). Back up your
# app settings ($APPDATA) — media can be re-downloaded. Database dumps for the database apps run nightly first.
source "$HS_ROOT/lib/service.sh"
BT="${BACKUP_TARGET:-$APPDATA/../backups}"
if [ "${HS_DRY_RUN:-0}" != 1 ]; then
  mkdir -p "$BT"
  if [ -d /etc/cron.d ]; then   # nightly database dumps into $APPDATA/_dumps, before the 04:15 backup
    echo "45 3 * * * root $HS_ROOT/scripts/db-dumps.sh >> /var/log/homelab-starter-dumps.log 2>&1" > /etc/cron.d/homelab-starter
  else echo "no /etc/cron.d: schedule $HS_ROOT/scripts/db-dumps.sh nightly yourself" >&2; fi
fi
recreate duplicati
docker run -d --name duplicati "${HS_COMMON[@]}" \
  -p 8200:8200 \
  -v "$APPDATA/duplicati:/config" \
  -v "$BT:/backups" \
  -v /:/source:ro,rslave \
  -e PUID=0 -e PGID=0 \
  -e SETTINGS_ENCRYPTION_KEY="$DUPLICATI_SETTINGS_KEY" \
  -e DUPLICATI__WEBSERVICE_PASSWORD="$ADMIN_PASSWORD" \
  -e DUPLICATI__WEBSERVICE_ALLOWED_HOSTNAMES='*' \
  lscr.io/linuxserver/duplicati:latest
