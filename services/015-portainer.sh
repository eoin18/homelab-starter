#!/usr/bin/env bash
# hs-name: Portainer (containers)
# hs-url: https://HOST:9443
# hs-group: System
source "$HS_ROOT/lib/service.sh"
recreate portainer
docker run -d --name portainer "${HS_COMMON[@]}" \
  -p 9443:9443 \
  -v "$APPDATA/portainer:/data" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  portainer/portainer-ce:lts
