#!/usr/bin/env bash
# hs-name: Home Assistant (smart home)
# hs-url: http://HOST:8123
# hs-group: Smart home
# Host network so device discovery (mDNS, Bluetooth, HomeKit) works.
source "$HS_ROOT/lib/service.sh"
DBUS=(); [ -S /run/dbus/system_bus_socket ] && DBUS=(-v /run/dbus:/run/dbus:ro)
recreate homeassistant
docker run -d --name homeassistant "${HS_COMMON[@]}" \
  --network host --privileged \
  -v "$APPDATA/homeassistant:/config" \
  "${DBUS[@]}" \
  ghcr.io/home-assistant/home-assistant:stable
