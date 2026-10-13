#!/usr/bin/env bash
# hs-name: Termix (web terminal + files)
# hs-url: http://HOST:8093
# hs-group: System
# Browser SSH terminal with tabs/splits and an SFTP file manager — also for managing other servers.
# A dedicated SSH key for it is created in $APPDATA/termix-ssh (see the Finish-setup page).
source "$HS_ROOT/lib/service.sh"
if [ "${HS_DRY_RUN:-0}" != 1 ]; then
  K="$APPDATA/termix-ssh/id_ed25519"; U="${SUDO_USER:-$ADMIN_SYSUSER}"; UH=$(getent passwd "$U" | cut -d: -f6)
  if [ ! -f "$K" ]; then mkdir -p "$(dirname "$K")"; ssh-keygen -q -t ed25519 -N '' -C "termix@$(hostname)" -f "$K"; fi
  if [ -n "$UH" ]; then mkdir -p "$UH/.ssh"; touch "$UH/.ssh/authorized_keys"
    grep -qF "$(cut -d' ' -f2 "$K.pub")" "$UH/.ssh/authorized_keys" || cat "$K.pub" >> "$UH/.ssh/authorized_keys"
    chown -R "$U": "$UH/.ssh"; chmod 700 "$UH/.ssh"; chmod 600 "$UH/.ssh/authorized_keys"; fi
fi
recreate termix
docker run -d --name termix "${HS_COMMON[@]}" \
  -p 8093:8080 \
  -v "$APPDATA/termix:/app/data" \
  ghcr.io/lukegus/termix:latest
