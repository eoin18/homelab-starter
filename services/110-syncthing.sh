#!/usr/bin/env bash
# hs-name: Syncthing (file sync)
# hs-url: http://HOST:8384
# hs-group: Files
# Syncs folders with your other devices. Synced data lives in $DATA/sync. Web UI login = shared admin (set by wiring).
source "$HS_ROOT/lib/service.sh"
[ "${HS_DRY_RUN:-0}" = 1 ] || { mkdir -p "$APPDATA/syncthing" "$DATA/sync"; chown -R "$PUID:$PGID" "$APPDATA/syncthing" "$DATA/sync"; }
recreate syncthing
docker run -d --name syncthing "${HS_COMMON[@]}" \
  -p 8384:8384 -p 22000:22000 -p 22000:22000/udp -p 21027:21027/udp \
  -v "$APPDATA/syncthing:/var/syncthing" \
  -v "$DATA/sync:/var/syncthing/data" \
  -e PUID="$PUID" -e PGID="$PGID" -e STNODEFAULTFOLDER=1 \
  syncthing/syncthing:latest
