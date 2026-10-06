#!/usr/bin/env bash
# Homepage dashboard + summary/CREDENTIALS.txt, driven by "# hs-*" headers in services/*.sh.

svc_meta() { { grep -m1 "^# hs-$2:" "$(service_script "$1")" 2>/dev/null || true; } | sed "s/^# hs-$2: *//"; }

homepage_render() {
  in_list homepage "$@" || return 0
  step "Dashboard"
  local cfg="$APPDATA/homepage/config" s g frag
  [ "$HS_DRY_RUN" = 1 ] && { info "[dry-run] would write $cfg"; return; }
  mkdir -p "$cfg"
  cat > "$cfg/settings.yaml" <<YAML
title: Home server
theme: dark
color: slate
headerStyle: clean
YAML
  printf 'my-docker:\n  socket: /var/run/docker.sock\n' > "$cfg/docker.yaml"
  printf -- '- resources:\n    cpu: true\n    memory: true\n    disk: /\n- search:\n    provider: duckduckgo\n' > "$cfg/widgets.yaml"
  : > "$cfg/bookmarks.yaml"
  local -A groups=(); local order=()
  for s in "$@"; do
    frag="$HS_ROOT/homepage/$s.yaml"; [ -f "$frag" ] && [ -n "$(service_script "$s")" ] || continue
    g=$(svc_meta "$s" group); g=${g:-Other}
    [ -n "${groups[$g]:-}" ] || order+=("$g")
    groups[$g]+="$(HOST_IP="$HOST_IP" envsubst < "$frag")"$'\n'
  done
  { for g in "${order[@]}"; do echo "- $g:"; printf '%s' "${groups[$g]}"; done; } > "$cfg/services.yaml"
  chown -R "$PUID:$PGID" "$APPDATA/homepage"
  ok "dashboard at http://$HOST_IP:3000"
}

summary_write() {
  step "Done"
  local f="$APPDATA/CREDENTIALS.txt" s name url
  local lines=("homelab-starter — $(date '+%Y-%m-%d %H:%M')" "" "Admin login for every app:" "  user:     $ADMIN_USER" "  password: $ADMIN_PASSWORD" "" "Apps:")
  for s in "$@"; do
    [ -n "$(service_script "$s")" ] || continue
    name=$(svc_meta "$s" name); url=$(svc_meta "$s" url)
    [ -n "$url" ] && lines+=("  $(printf '%-22s' "${name:-$s}") ${url//HOST/$HOST_IP}")
  done
  lines+=("" "Settings: $HS_CONFIG   Secrets: $(secrets_file)" "Re-run: sudo $HS_ROOT/install.sh   (--reconfigure, --add <bundle>, --status)")
  if [ "$HS_DRY_RUN" != 1 ]; then printf '%s\n' "${lines[@]}" > "$f"; chmod 600 "$f"; fi
  printf '    %s\n' "${lines[@]}"
  echo; if [ "$HS_DRY_RUN" = 1 ]; then info "(dry run: nothing was saved)"; else info "this summary is saved in $f (readable by root only)"; fi
}
