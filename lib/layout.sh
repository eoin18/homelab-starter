#!/usr/bin/env bash
# Folder layout + ownership. Never formats or mounts anything: paths only.

layout_create() {  # layout_create <bundle...>
  step "Folders and permissions"
  local g; g=$(getent group "$PGID" | cut -d: -f1)
  if [ -z "$g" ]; then
    if getent group media >/dev/null; then die "group 'media' exists with a different id than PGID=$PGID"; fi
    run groupadd -g "$PGID" media && g=media
  fi
  run usermod -aG "$g" "$ADMIN_SYSUSER"
  local dirs=("$APPDATA")
  in_list movies-tv "$@" && dirs+=("${DATA_MOVIES:-$DATA/movies}"/{library,downloads} "${DATA_TV:-$DATA/tv}"/{library,downloads})
  in_list media-server "$@" && dirs+=("${DATA_MOVIES:-$DATA/movies}/library" "${DATA_TV:-$DATA/tv}/library")
  in_list books "$@" && dirs+=("${DATA_BOOKS:-$DATA/books}"/{library,ingest,downloads})
  in_list games "$@" && dirs+=("${DATA_ROMS:-$DATA/roms}"/library/{roms,bios})
  local d
  for d in $(printf '%s\n' "${dirs[@]}" | awk '!s[$0]++'); do
    [ -d "$d" ] || run mkdir -p "$d"
  done
  if [ "$HS_DRY_RUN" != 1 ] && [ -d "$DATA" ]; then
    chown "$PUID:$PGID" "$DATA"; chmod 2775 "$DATA"
    find "$DATA" -maxdepth 3 -type d \( ! -user "$PUID" -o ! -perm -2775 \) -exec chown "$PUID:$PGID" {} + -exec chmod 2775 {} + 2>/dev/null || true
  fi
  [ "$HS_DRY_RUN" = 1 ] || chmod 755 "$APPDATA"
  ok "data under $DATA, app settings under $APPDATA"
}
