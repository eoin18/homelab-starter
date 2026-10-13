#!/usr/bin/env bash
# hs-name: Pi-hole (DNS + ad blocking)
# hs-url: http://HOST:8053/admin
# hs-group: Network
# Needs port 53: Ubuntu's own DNS stub (systemd-resolved) is moved out of the way first. Web UI on 8053.
# Point your router's DNS at this server afterwards (Finish-setup page).
source "$HS_ROOT/lib/service.sh"
if [ "${HS_DRY_RUN:-0}" != 1 ] && systemctl is-active -q systemd-resolved 2>/dev/null && ss -lntu 2>/dev/null | grep -q '127.0.0.53:53'; then
  mkdir -p /etc/systemd/resolved.conf.d
  printf '[Resolve]\nDNSStubListener=no\n' > /etc/systemd/resolved.conf.d/homelab-starter-pihole.conf
  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
  systemctl restart systemd-resolved
fi
recreate pihole
docker run -d --name pihole "${HS_COMMON[@]}" \
  --network host --cap-add NET_ADMIN \
  -v "$APPDATA/pihole/etc-pihole:/etc/pihole" \
  -v "$APPDATA/pihole/etc-dnsmasq.d:/etc/dnsmasq.d" \
  -e FTLCONF_webserver_api_password="$ADMIN_PASSWORD" \
  -e FTLCONF_webserver_port=8053 \
  -e FTLCONF_dns_listeningMode=all \
  pihole/pihole:latest
