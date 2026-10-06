#!/usr/bin/env bash
# hs-name: qBittorrent (downloads)
# hs-url: http://HOST:8085
# hs-group: Downloads
source "$HS_ROOT/lib/service.sh"
C="$APPDATA/qbittorrent/qBittorrent"
if [ "${HS_DRY_RUN:-0}" != 1 ] && [ ! -e "$C/qBittorrent.conf" ]; then
  # Pre-seed before first start: admin login (PBKDF2-SHA512), auto save paths, seeding rules, categories.
  HASH=$(python3 -c 'import hashlib,os,base64,sys; s=os.urandom(16); h=hashlib.pbkdf2_hmac("sha512",sys.argv[1].encode(),s,100000); print(base64.b64encode(s).decode()+":"+base64.b64encode(h).decode())' "$ADMIN_PASSWORD")
  write_once "$C/qBittorrent.conf" <<CONF
[BitTorrent]
Session\DefaultSavePath=$DATA/downloads
Session\DisableAutoTMMByDefault=false
Session\GlobalMaxRatio=1
Session\ShareLimitAction=Stop
Session\Port=6881
Session\QueueingSystemEnabled=true

[Preferences]
WebUI\Port=8085
WebUI\Username=$ADMIN_USER
WebUI\Password_PBKDF2="@ByteArray($HASH)"
WebUI\LocalHostAuth=true
CONF
  cat_json() { printf '"%s": {"save_path": "%s", "download_path": null, "ratio_limit": 1, "share_limit_action": "Remove", "seeding_time_limit": -2, "inactive_seeding_time_limit": -2}' "$1" "$2"; }
  write_once "$C/categories.json" <<JSON
{ $(cat_json movies "$DATA_MOVIES/downloads"), $(cat_json tv "$DATA_TV/downloads"), $(cat_json books "$DATA_BOOKS/downloads") }
JSON
  mkdir -p "$DATA/downloads"; chown "$PUID:$PGID" "$DATA/downloads"; chmod 2775 "$DATA/downloads"
  chown -R "$PUID:$PGID" "$APPDATA/qbittorrent"
fi
recreate qbittorrent
docker run -d --name qbittorrent "${HS_COMMON[@]}" "${HS_IDS[@]}" \
  -p 8085:8085 -p 6881:6881 -p 6881:6881/udp \
  -e WEBUI_PORT=8085 -e TORRENTING_PORT=6881 \
  -v "$APPDATA/qbittorrent:/config" \
  "${HS_DATA_MOUNTS[@]}" \
  lscr.io/linuxserver/qbittorrent:latest
