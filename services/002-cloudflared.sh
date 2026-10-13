#!/usr/bin/env bash
# hs-name: Cloudflare tunnel
# hs-group: Network
# Connects to your Cloudflare tunnel (token from the Zero Trust dashboard). Add public hostnames + Access policies there.
source "$HS_ROOT/lib/service.sh"
recreate cloudflared
docker run -d --name cloudflared "${HS_COMMON[@]}" \
  --network host \
  cloudflare/cloudflared:latest tunnel --no-autoupdate run --token "${CF_TUNNEL_TOKEN:-}"
