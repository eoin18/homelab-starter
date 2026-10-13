#!/usr/bin/env bash
# hs-name: Mosquitto (MQTT broker)
# hs-group: Smart home
# Message broker for Zigbee2MQTT and Home Assistant. Home network only (anonymous); don't expose port 1883 to the internet.
source "$HS_ROOT/lib/service.sh"
printf 'persistence true\npersistence_location /mosquitto/data/\nlistener 1883\nallow_anonymous true\n' | write_once "$APPDATA/mosquitto/config/mosquitto.conf"
recreate mosquitto
docker run -d --name mosquitto "${HS_COMMON[@]}" \
  -p 1883:1883 \
  -v "$APPDATA/mosquitto/config:/mosquitto/config" \
  -v "$APPDATA/mosquitto/data:/mosquitto/data" \
  -v "$APPDATA/mosquitto/log:/mosquitto/log" \
  eclipse-mosquitto:latest
