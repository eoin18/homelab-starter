#!/usr/bin/env bash
# hs-name: Scrypted (cameras)
# hs-url: https://HOST:10443
# hs-group: Smart home
# Cameras/doorbells into Home Assistant, HomeKit and Google Home. Host network for discovery; GPU for video if present.
source "$HS_ROOT/lib/service.sh"
GPU_ARGS=(); [ "${GPU:-none}" = yes ] && GPU_ARGS=(--device /dev/dri:/dev/dri)
AVAHI=(); [ -S /var/run/avahi-daemon/socket ] && AVAHI=(-v /var/run/avahi-daemon/socket:/var/run/avahi-daemon/socket)
DBUS=(); [ -d /var/run/dbus ] && DBUS=(-v /var/run/dbus:/var/run/dbus)
recreate scrypted
docker run -d --name scrypted "${HS_COMMON[@]}" \
  --network host --security-opt apparmor=unconfined \
  "${GPU_ARGS[@]}" "${AVAHI[@]}" "${DBUS[@]}" \
  -v "$APPDATA/scrypted:/server/volume" \
  ghcr.io/koush/scrypted:latest
