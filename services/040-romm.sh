#!/usr/bin/env bash
# hs-name: RomM (games library)
# hs-url: http://HOST:8090
# hs-group: Games
# ROM library with metadata and in-browser play. Put ROMs in $DATA_ROMS/library/roms/<platform>/.
source "$HS_ROOT/lib/service.sh"
docker network inspect romm >/dev/null 2>&1 || docker network create romm >/dev/null
recreate romm
docker run -d --name romm "${HS_COMMON[@]}" --network romm \
  -p 8090:8080 \
  -v "$APPDATA/romm/data:/romm" \
  -v "$APPDATA/romm/redis:/redis-data" \
  -v "$APPDATA/romm/assets:/romm/assets" \
  -v "$APPDATA/romm/config:/romm/config" \
  -v "$APPDATA/romm/resources:/romm/resources" \
  -v "$DATA_ROMS/library:/romm/library" \
  -e DB_HOST=romm-db -e DB_NAME=romm -e DB_USER=romm -e DB_PASSWD="$ROMM_DB_PASSWORD" -e DB_PORT=3306 \
  -e ROMM_AUTH_SECRET_KEY="$ROMM_AUTH_SECRET_KEY" \
  -e ENABLE_SCHEDULED_RESCAN=true -e HASHEOUS_API_ENABLED=true -e PLAYMATCH_API_ENABLED=true \
  -e LAUNCHBOX_API_ENABLED=true -e HLTB_API_ENABLED=true -e WEB_SERVER_CONCURRENCY=2 \
  rommapp/romm:latest
