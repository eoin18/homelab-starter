#!/usr/bin/env bash
# hs-name: Zigbee2MQTT (Zigbee devices)
# hs-url: http://HOST:8099
# hs-group: Smart home
# ZIGBEE_DEVICE = /dev/serial/by-id/... (USB stick) or tcp://IP:PORT (network coordinator). Pre-wired to Mosquitto + HA.
source "$HS_ROOT/lib/service.sh"
DEV=(); case "${ZIGBEE_DEVICE:-}" in
  /dev/*) [ -e "$ZIGBEE_DEVICE" ] || [ "${HS_DRY_RUN:-0}" = 1 ] || { echo "Zigbee stick $ZIGBEE_DEVICE not found: plug it in and re-run the installer" >&2; exit 1; }
          DEV=(--device "$ZIGBEE_DEVICE:$ZIGBEE_DEVICE") ;;
esac
write_once "$APPDATA/zigbee2mqtt/configuration.yaml" <<YML
version: 4
homeassistant:
  enabled: true
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://host.docker.internal:1883
serial:
  port: ${ZIGBEE_DEVICE:-/dev/ttyUSB0}
frontend:
  enabled: true
  port: 8080
  auth_token: ${ADMIN_PASSWORD}
permit_join: false
advanced:
  network_key: GENERATE
  pan_id: GENERATE
  ext_pan_id: GENERATE
YML
recreate zigbee2mqtt
docker run -d --name zigbee2mqtt "${HS_COMMON[@]}" \
  -p 8099:8080 \
  "${DEV[@]}" \
  -v "$APPDATA/zigbee2mqtt:/app/data" \
  koenkk/zigbee2mqtt:latest
