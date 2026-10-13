#!/usr/bin/env bash
# hs-name: Tailscale (private remote access)
# hs-group: Network
# Joins your tailnet so your own devices reach every app from anywhere. TS_AUTHKEY joins automatically; without it,
# run `sudo docker exec tailscale tailscale up` once and open the login link it prints.
source "$HS_ROOT/lib/service.sh"
recreate tailscale
docker run -d --name tailscale "${HS_COMMON[@]}" \
  --network host --cap-add NET_ADMIN --cap-add SYS_MODULE --device /dev/net/tun:/dev/net/tun \
  -v "$APPDATA/tailscale:/var/lib/tailscale" \
  -e TS_STATE_DIR=/var/lib/tailscale -e TS_USERSPACE=false -e TS_HOSTNAME="$(hostname)" \
  ${TS_AUTHKEY:+-e TS_AUTHKEY="$TS_AUTHKEY"} \
  tailscale/tailscale:latest
