#!/usr/bin/env bash
# hs-name: Gluetun (torrent VPN)
# hs-group: Downloads
# qBittorrent runs inside this container's network, so torrent traffic only ever leaves through the VPN
# (no tunnel = no internet: kill switch). qBittorrent's web UI port is published here instead.
# VPN_SERVICE_PROVIDER (default protonvpn), VPN_WIREGUARD_PRIVATE_KEY (secret), VPN_SERVER_COUNTRIES,
# VPN_PORT_FORWARDING=on|off. A forwarded port is copied into qBittorrent's listen port on every reconnect.
source "$HS_ROOT/lib/service.sh"
PROVIDER="${VPN_SERVICE_PROVIDER:-protonvpn}" PF="${VPN_PORT_FORWARDING:-on}"
PF_ARGS=(-e VPN_PORT_FORWARDING="$PF")
if [ "$PF" = on ]; then
  PF_ARGS+=(-e VPN_PORT_FORWARDING_STATUS_FILE=/gluetun/forwarded_port -e "VPN_PORT_FORWARDING_UP_COMMAND=/bin/sh /gluetun/qbt-port.sh {{PORT}}")
  case "$PROVIDER" in protonvpn|"private internet access") PF_ARGS+=(-e PORT_FORWARD_ONLY=on) ;; esac
  if [ "${HS_DRY_RUN:-0}" != 1 ] && [ "${HS_RENDER:-0}" != 1 ]; then
    mkdir -p "$APPDATA/gluetun"
    # qBittorrent shares this network namespace, so 127.0.0.1 is qBittorrent (localhost auth is off in VPN mode)
    cat > "$APPDATA/gluetun/qbt-port.sh" <<'SH'
#!/bin/sh
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  wget -q -O /dev/null --post-data "json={\"listen_port\":$1}" http://127.0.0.1:8085/api/v2/app/setPreferences && exit 0
  sleep 10   # qBittorrent may still be starting
done
SH
  fi
fi
# Control API (status, public IP, forwarded port) for the dashboard widget: read-only routes behind an API key,
# published only on the docker bridge gateway (host.docker.internal), not on the LAN.
if [ "${HS_DRY_RUN:-0}" != 1 ] && [ "${HS_RENDER:-0}" != 1 ]; then
  mkdir -p "$APPDATA/gluetun/auth"
  ( umask 077; cat > "$APPDATA/gluetun/auth/config.toml" <<TOML
[[roles]]
name = "dashboard"
routes = ["GET /v1/publicip/ip", "GET /v1/portforward", "GET /v1/openvpn/portforwarded", "GET /v1/vpn/status"]
auth = "apikey"
apikey = "${GLUETUN_API_KEY:-}"
TOML
  )
fi
GW=$(command docker network inspect bridge -f '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || echo 172.17.0.1)
recreate gluetun
docker run -d --name gluetun "${HS_COMMON[@]}" \
  --cap-add NET_ADMIN --device /dev/net/tun:/dev/net/tun \
  -p 8085:8085 -p "$GW:8000:8000" \
  -e VPN_SERVICE_PROVIDER="$PROVIDER" -e VPN_TYPE=wireguard \
  -e WIREGUARD_PRIVATE_KEY="${VPN_WIREGUARD_PRIVATE_KEY:-}" \
  -e SERVER_COUNTRIES="${VPN_SERVER_COUNTRIES:-}" \
  "${PF_ARGS[@]}" \
  -v "$APPDATA/gluetun:/gluetun" \
  qmcgaw/gluetun:v3
