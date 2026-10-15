#!/usr/bin/env bash
# whiptail menus. Fills config variables, then config_write saves them.

WT_TITLE="homelab-starter"
wt() { whiptail --title "$WT_TITLE" "$@" 3>&1 1>&2 2>&3; }
wt_or_quit() { local r; r=$(wt "$@") || { clear; die "cancelled — nothing was installed"; }; printf '%s' "$r"; }

menu_run() {
  local warn=""
  [ "$DET_IS_VM" = 1 ] && warn+="\n• Running in a VM: use bridged networking; no GPU transcoding; keep the host awake."
  [ "$DET_OS_SUPPORTED" = full ] || warn+="\n• $DET_OS_NAME is best effort: Docker must already be installed."
  [ "$DET_RAM_MB" -lt 4000 ] && warn+="\n• Under 4 GB RAM: pick only a few bundles."
  wt --msgbox "Welcome! This sets up a home server from bundles of apps, wired together.\n\nDetected:\n$(detect_summary)${warn:+\n\nNotes:$warn}" 22 78

  # 1. Bundles
  local items=() b on
  for b in $(bundle_ids); do
    [ "$(bundle_get "$b" VISIBLE)" = 1 ] || continue
    in_list "$b" ${BUNDLES:-} && on=ON || on=OFF
    items+=("$b" "$(bundle_get "$b" NAME) — $(bundle_get "$b" DESC)" "$on")
  done
  local picked; picked=$(wt_or_quit --separate-output --checklist "Pick bundles (space to toggle). Anything they need is added automatically." 24 100 15 "${items[@]}")
  BUNDLES=$(echo $picked)
  local resolved; resolved=$(bundles_resolve $BUNDLES | tr '\n' ' ')
  local ram; ram=$(bundles_ram_mb $resolved)
  wt --yesno "Will install: $resolved\n\nEstimated RAM: ~$((ram/1024)).$(( (ram%1024)*10/1024 )) GB (this machine: $((DET_RAM_MB/1024)) GB).\n\nContinue?" 14 78 || { clear; die "cancelled"; }

  # 2. Storage
  local disks; disks=$(detect_disks | awk '{printf "  %-24s %5s GB free of %s GB\n",$1,$2,$3}')
  DATA=$(wt_or_quit --inputbox "Where should media live (movies, TV, books, ROMs)?\nPick a folder on your biggest disk:\n\n$disks" 20 78 "${DATA:-/data}")
  APPDATA=$(wt_or_quit --inputbox "Where should app settings live? (small, keep it on a fast disk; back it up)" 10 78 "${APPDATA:-/srv/appdata}")

  # 3. Basics
  TZ=$(wt_or_quit --inputbox "Timezone" 8 60 "${TZ:-$DET_TZ}")
  ADMIN_USER=$(wt_or_quit --inputbox "Admin username — used to log in to every app" 8 60 "${ADMIN_USER:-admin}")
  if wt --yesno "Generate a strong admin password for you?\n(No = type your own)" 9 60; then
    ADMIN_PASSWORD="$(gen_secret 20)"
  else
    local p1 p2
    while :; do
      p1=$(wt_or_quit --passwordbox "Admin password (at least 10 characters)" 8 60); p2=$(wt_or_quit --passwordbox "Repeat password" 8 60)
      [ "$p1" = "$p2" ] && [ ${#p1} -ge 10 ] && break
      wt --msgbox "Passwords didn't match or were too short — try again." 8 60
    done
    ADMIN_PASSWORD="$p1"
  fi

  # 4. Remote access
  REMOTE=$(wt_or_quit --radiolist "Remote access (from outside your home)" 14 78 3 \
    none "No remote access (home network only)" "$([ "${REMOTE:-none}" = none ] && echo ON || echo OFF)" \
    tailscale "Tailscale — private access from your own devices (recommended)" "$([ "${REMOTE:-}" = tailscale ] && echo ON || echo OFF)" \
    cloudflare "Cloudflare tunnel — public URLs on your domain (advanced)" "$([ "${REMOTE:-}" = cloudflare ] && echo ON || echo OFF)")
  case "$REMOTE" in
    tailscale) BUNDLES="$BUNDLES remote-tailscale"
      TS_AUTHKEY=$(wt_or_quit --inputbox "Tailscale auth key (optional — leave empty to get a login link at the end)" 9 78 "${TS_AUTHKEY:-}") ;;
    cloudflare) BUNDLES="$BUNDLES remote-cloudflare"
      CF_DOMAIN=$(wt_or_quit --inputbox "Your domain on Cloudflare (e.g. example.com)" 8 70 "${CF_DOMAIN:-}")
      CF_TUNNEL_TOKEN=$(wt_or_quit --inputbox "Cloudflare tunnel token (Zero Trust → Networks → Tunnels → your tunnel)" 9 78 "${CF_TUNNEL_TOKEN:-}")
      CF_API_TOKEN=$(wt_or_quit --inputbox "Cloudflare API token (optional: lets the installer create routes + Access rules)" 9 78 "${CF_API_TOKEN:-}") ;;
  esac

  # 5. Bundle questions
  if in_list zigbee $BUNDLES; then
    ZIGBEE_DEVICE=$(wt_or_quit --inputbox "Zigbee coordinator: a /dev/serial/by-id/... path, or tcp://IP:6638 for a network coordinator" 10 90 "${ZIGBEE_DEVICE:-${DET_ZIGBEE:-}}")
  fi
  if in_list torrent-vpn $BUNDLES; then
    VPN_SERVICE_PROVIDER=$(wt_or_quit --inputbox "VPN provider, as Gluetun names it (protonvpn, airvpn, private internet access, ...). Port forwarding works with protonvpn, airvpn and PIA." 10 90 "${VPN_SERVICE_PROVIDER:-protonvpn}")
    VPN_WIREGUARD_PRIVATE_KEY=$(wt_or_quit --passwordbox "WireGuard private key from your provider's WireGuard config (Proton: create it with NAT-PMP on)" 9 90)
    VPN_SERVER_COUNTRIES=$(wt_or_quit --inputbox "Server countries, comma-separated (nearby is fastest, e.g. Ireland,United Kingdom)" 9 90 "${VPN_SERVER_COUNTRIES:-}")
  fi
  if in_list backup $BUNDLES; then
    BACKUP_TARGET=$(wt_or_quit --inputbox "Backup destination folder (another disk is best). You can add cloud targets later in Duplicati." 9 78 "${BACKUP_TARGET:-/mnt/backup}")
  fi

  # 6. Review
  local resolved2; resolved2=$(bundles_resolve $BUNDLES | tr '\n' ' ')
  wt --yesno "Ready to install:\n\nBundles:   $resolved2\nMedia:     $DATA\nSettings:  $APPDATA\nTimezone:  $TZ\nAdmin:     $ADMIN_USER\nRemote:    $REMOTE\n\nInstall now?" 18 78 || { clear; die "cancelled — your answers were not saved"; }
  clear
}

config_write() {
  local f="$HS_CONFIG" k
  [ "$HS_DRY_RUN" = 1 ] && { info "[dry-run] would write $f"; return; }
  : > "$f"; chmod 600 "$f"
  echo "# homelab-starter settings — edit and re-run install.sh, or run install.sh --reconfigure" >> "$f"
  for k in BUNDLES TZ PUID PGID DATA DATA_MOVIES DATA_TV DATA_BOOKS DATA_ROMS APPDATA ADMIN_USER GPU ZIGBEE_DEVICE REMOTE TS_AUTHKEY CF_DOMAIN CF_TUNNEL_TOKEN CF_API_TOKEN BACKUP_TARGET VPN_SERVICE_PROVIDER VPN_WIREGUARD_PRIVATE_KEY VPN_SERVER_COUNTRIES VPN_PORT_FORWARDING; do
    env_set "$f" "$k" "${!k:-}"
  done
}
