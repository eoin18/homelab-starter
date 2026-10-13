#!/usr/bin/env bash
# hs-name: Beszel (server monitoring)
# hs-url: http://HOST:8091
# hs-group: Monitoring
# Hub; the agent (131-beszel-agent) talks to it over a shared unix socket — no metrics port is opened.
source "$HS_ROOT/lib/service.sh"
recreate beszel
docker run -d --name beszel "${HS_COMMON[@]}" \
  -p 8091:8090 \
  -v "$APPDATA/beszel/data:/beszel_data" \
  -v "$APPDATA/beszel/socket:/beszel_socket" \
  henrygd/beszel:latest
