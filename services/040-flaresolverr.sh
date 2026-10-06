#!/usr/bin/env bash
# hs-name: FlareSolverr
# hs-group: Downloads
source "$HS_ROOT/lib/service.sh"
recreate flaresolverr
docker run -d --name flaresolverr "${HS_COMMON[@]}" \
  -p 8191:8191 \
  -e LOG_LEVEL=info \
  ghcr.io/flaresolverr/flaresolverr:latest
