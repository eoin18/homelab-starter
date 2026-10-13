#!/usr/bin/env bash
# hs-name: Dozzle (container logs)
# hs-url: http://HOST:8092
# hs-group: Monitoring
source "$HS_ROOT/lib/service.sh"
recreate dozzle
docker run -d --name dozzle "${HS_COMMON[@]}" \
  -p 8092:8080 \
  -v "$APPDATA/dozzle:/data" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -e DOZZLE_NO_ANALYTICS=true \
  amir20/dozzle:latest
