#!/usr/bin/env bash
# hs-name: Speedtest Tracker (internet speed history)
# hs-url: http://HOST:8080
# hs-group: Monitoring
source "$HS_ROOT/lib/service.sh"
recreate speedtest-tracker
docker run -d --name speedtest-tracker "${HS_COMMON[@]}" \
  -p 8080:80 \
  -v "$APPDATA/speedtest-tracker:/config" \
  "${HS_IDS[@]}" \
  -e APP_KEY="base64:$(printf %s "$SPEEDTEST_KEY_SEED" | base64)" \
  -e DB_CONNECTION=sqlite \
  -e SPEEDTEST_SCHEDULE='30 * * * *' \
  lscr.io/linuxserver/speedtest-tracker:latest
