#!/usr/bin/env bash
# homelab-starter installer. Usage: sudo ./install.sh [--reconfigure] [--add <bundle>] [--remove <bundle>]
#                                                    [--status] [--dry-run] [--help]
set -euo pipefail
HS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export HS_ROOT
for l in common pkg detect bundles secrets layout docker menu; do . "$HS_ROOT/lib/$l.sh"; done

RECONF=0; ADD=(); REMOVE=(); STATUS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --reconfigure) RECONF=1 ;;
    --add) ADD+=("$2"); shift ;;
    --remove) REMOVE+=("$2"); shift ;;
    --status) STATUS=1 ;;
    --dry-run) HS_DRY_RUN=1 ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) die "unknown option $1 (try --help)" ;;
  esac; shift
done
export HS_DRY_RUN

[ "$HS_DRY_RUN" = 1 ] || require_root
detect_all
case "$DET_ARCH" in amd64|arm64) ;; *) die "unsupported CPU architecture $DET_ARCH (x86_64 or arm64 needed)";; esac

# ---------- configuration ----------
env_load "$HS_CONFIG"
ADMIN_SYSUSER="$DET_USER"; PUID="${PUID:-$DET_UID}"; PGID="${PGID:-1001}"
if [ ! -f "$HS_CONFIG" ] || [ "$RECONF" = 1 ]; then
  [ -t 0 ] || die "no config.env and no terminal for the menus. Copy config.env.example to config.env, or run interactively."
  pkg_install whiptail
  menu_run
  config_write
fi
for b in "${ADD[@]}"; do BUNDLES="$BUNDLES $b"; done
for b in "${REMOVE[@]}"; do BUNDLES=$(echo " $BUNDLES " | sed "s/ $b / /g"); done
if [ ${#ADD[@]} -gt 0 ] || [ ${#REMOVE[@]} -gt 0 ]; then BUNDLES=$(echo $BUNDLES); config_write; fi
: "${BUNDLES:=}"; : "${DATA:=/data}"; : "${APPDATA:=/srv/appdata}"; : "${TZ:=$DET_TZ}"; : "${ADMIN_USER:=admin}"
: "${GPU:=auto}"; : "${REMOTE:=none}"
[ "$GPU" = auto ] && { [ "$DET_GPU" = 1 ] && GPU=yes || GPU=none; }
HOST_IP="${HOST_IP:-$DET_HOST_IP}"
export BUNDLES DATA APPDATA TZ ADMIN_USER PUID PGID GPU REMOTE HOST_IP DATA_MOVIES DATA_TV DATA_BOOKS DATA_ROMS ZIGBEE_DEVICE TS_AUTHKEY CF_DOMAIN CF_TUNNEL_TOKEN CF_API_TOKEN BACKUP_TARGET 2>/dev/null || true

mapfile -t RESOLVED < <(bundles_resolve $BUNDLES)
mapfile -t SERVICES < <(bundles_services "${RESOLVED[@]}")
service_script() { ls "$HS_ROOT"/services/*-"$1".sh 2>/dev/null | head -1; }

if [ "$STATUS" = 1 ]; then
  step "Status"; for s in "${SERVICES[@]}"; do printf '    %-24s %s\n' "$s" "$(docker inspect -f '{{.State.Status}}' "$s" 2>/dev/null || echo 'not installed')"; done; exit 0
fi

step "Plan"
info "bundles:  ${RESOLVED[*]}"
info "services: ${SERVICES[*]}"
ram=$(bundles_ram_mb "${RESOLVED[@]}")
info "RAM estimate ~${ram} MB of ${DET_RAM_MB} MB"
[ "$ram" -gt "$DET_RAM_MB" ] && warn "the chosen bundles may need more RAM than this machine has"

# ---------- system ----------
step "Packages"; pkg_install curl git envsubst; ok "curl, git, envsubst"
docker_ensure
layout_create "${RESOLVED[@]}"

# ---------- secrets ----------
step "Secrets"
[ "$HS_DRY_RUN" = 1 ] || mkdir -p "$APPDATA"
if [ -n "${ADMIN_PASSWORD:-}" ] && [ "$HS_DRY_RUN" != 1 ]; then env_set "$(secrets_file)" ADMIN_PASSWORD "$ADMIN_PASSWORD"; fi
secret_ensure ADMIN_PASSWORD 20
env_load "$(secrets_file)"; set -a; env_load "$(secrets_file)"; set +a
ok "secrets in $(secrets_file)"

# ---------- services (in script-number order) ----------
step "Services"
docker network inspect homelab >/dev/null 2>&1 || run docker network create homelab >/dev/null
pending=()
for f in $(for s in "${SERVICES[@]}"; do service_script "$s"; done | sort); do
  n=$(basename "$f" .sh); n=${n#*-}
  if bash "$f" >/dev/null; then ok "$n"; else warn "$n failed to start (see: docker logs $n)"; fi
done
for s in "${SERVICES[@]}"; do [ -n "$(service_script "$s")" ] || pending+=("$s"); done
[ ${#pending[@]} -eq 0 ] || warn "not available in this version yet: ${pending[*]}"

# ---------- wiring ----------
step "Wiring apps together"
for s in "${SERVICES[@]}"; do
  w="$HS_ROOT/wire/$s.sh"; [ -f "$w" ] || continue
  if [ "$HS_DRY_RUN" = 1 ]; then info "[dry-run] would wire $s"; continue; fi
  if bash "$w"; then ok "$s"; else warn "wiring $s failed — re-run install.sh to retry"; fi
done

# ---------- dashboard + summary ----------
. "$HS_ROOT/lib/finish.sh"
homepage_render "${SERVICES[@]}"
summary_write "${SERVICES[@]}"
