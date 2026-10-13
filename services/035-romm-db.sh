#!/usr/bin/env bash
# hs-name: RomM database
# hs-group: Games
source "$HS_ROOT/lib/service.sh"
docker network inspect romm >/dev/null 2>&1 || docker network create romm >/dev/null
recreate romm-db
docker run -d --name romm-db "${HS_COMMON[@]}" --network romm \
  --health-cmd 'healthcheck.sh --connect --innodb_initialized' --health-interval 10s --health-timeout 5s --health-start-period 30s --health-retries 5 \
  -v "$APPDATA/romm-db:/var/lib/mysql" \
  -e MARIADB_ROOT_PASSWORD="$ROMM_DB_ROOT_PASSWORD" -e MARIADB_DATABASE=romm -e MARIADB_USER=romm -e MARIADB_PASSWORD="$ROMM_DB_PASSWORD" \
  mariadb:11
