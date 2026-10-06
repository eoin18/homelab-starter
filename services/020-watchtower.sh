#!/usr/bin/env bash
# hs-name: Watchtower (auto-updates)
# hs-group: System
source "$HS_ROOT/lib/service.sh"
recreate watchtower
docker run -d --name watchtower "${HS_COMMON[@]}" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_CLEANUP=true \
  -e WATCHTOWER_SCHEDULE='0 0 4 * * *' \
  nickfedor/watchtower:latest
