#!/usr/bin/env bash
# homelab-starter installer. Usage: sudo ./install.sh [--reconfigure] [--add <bundle>] [--remove <bundle>]
#                                                    [--status] [--dry-run] [--help]
#        sudo ./install.sh --profile <dir>     non-interactive install from a saved profile (see docs/profiles.md)
#             ./install.sh --render --profile <dir>   print the exact docker run commands, change nothing
#             ./install.sh [--profile <dir>] --only <name> [--only ...]   recreate just these containers
set -eu   # no pipefail: a "no match" mid-pipeline (grep, getent, ls) must not abort silently
HS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export HS_ROOT
for l in common pkg detect bundles secrets layout docker menu; do . "$HS_ROOT/lib/$l.sh"; done

RECONF=0; ADD=(); REMOVE=(); STATUS=0; RENDER=0; ONLY=()
while [ $# -gt 0 ]; do
  case "$1" in
    --reconfigure) RECONF=1 ;;
    --add) ADD+=("$2"); shift ;;
    --remove) REMOVE+=("$2"); shift ;;
    --status) STATUS=1 ;;
    --dry-run) HS_DRY_RUN=1 ;;
    --profile) HS_PROFILE=$(cd "$2" && pwd) || die "no profile folder $2"; HS_CONFIG="$HS_PROFILE/profile.env"; shift ;;
    --render) RENDER=1; HS_DRY_RUN=1 ;;
    --only) ONLY+=("$2"); shift ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) die "unknown option $1 (try --help)" ;;
  esac; shift
done
export HS_DRY_RUN HS_PROFILE="${HS_PROFILE:-}" HS_CONFIG
if [ -n "$HS_PROFILE" ]; then [ -f "$HS_CONFIG" ] || die "$HS_CONFIG missing"; fi
[ "$RENDER" = 1 ] && exec 3>&1 1>&2   # --render: commands on stdout, everything else on stderr

if [ ${#ONLY[@]} -gt 0 ]; then   # recreating a few containers needs Docker access, not root
  [ "$HS_DRY_RUN" = 1 ] || command docker info >/dev/null 2>&1 || die "no access to Docker (use sudo or join the docker group)"
  [ "$(id -u)" -eq 0 ] || HS_SECRETS_RO=1; export HS_SECRETS_RO
else
  [ "$HS_DRY_RUN" = 1 ] || require_root
fi
detect_all
case "$DET_ARCH" in amd64|arm64) ;; *) die "unsupported CPU architecture $DET_ARCH (x86_64 or arm64 needed)";; esac

# ---------- configuration ----------
env_load "$HS_CONFIG"
[ -n "${SECRETS_ENV:-}" ] && env_load "${SECRETS_ENV/#\~/$HOME}"   # profile: values its overrides reference
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
DATA_MOVIES="${DATA_MOVIES:-$DATA/movies}"; DATA_TV="${DATA_TV:-$DATA/tv}"; DATA_BOOKS="${DATA_BOOKS:-$DATA/books}"; DATA_ROMS="${DATA_ROMS:-$DATA/roms}"; DATA_PHOTOS="${DATA_PHOTOS:-$DATA/photos}"; DATA_MUSIC="${DATA_MUSIC:-$DATA/music}"
export BUNDLES DATA APPDATA TZ ADMIN_USER PUID PGID GPU REMOTE HOST_IP DATA_MOVIES DATA_TV DATA_BOOKS DATA_ROMS DATA_PHOTOS DATA_MUSIC ZIGBEE_DEVICE TS_AUTHKEY CF_DOMAIN CF_TUNNEL_TOKEN CF_API_TOKEN BACKUP_TARGET 2>/dev/null || true

mapfile -t RESOLVED < <(bundles_resolve $BUNDLES)
mapfile -t SERVICES < <(bundles_services "${RESOLVED[@]}")
if [ -n "${EXCLUDE:-}" ]; then   # profile: catalogue services this machine does not run
  mapfile -t SERVICES < <(printf '%s\n' "${SERVICES[@]}" | grep -vxF -f <(printf '%s\n' $EXCLUDE) || true)
fi
EXTRAS=(); [ -n "$HS_PROFILE" ] && [ -d "$HS_PROFILE/extras" ] && mapfile -t EXTRAS < <(ls "$HS_PROFILE"/extras/*.sh 2>/dev/null | sort)
skipped() { in_list "$1" ${SKIP_STEPS:-}; }   # profile: installer steps to leave out (layout wiring dashboard summary)
service_script() { ls "$HS_ROOT"/services/*-"$1".sh 2>/dev/null | head -1; }
svc_name() { basename "$1" .sh | sed 's/^[0-9]*-//'; }
# service scripts in start order (catalogue by number, then the profile's extras), limited by --only
svc_files() {
  local f
  for f in $(for s in "${SERVICES[@]}"; do service_script "$s"; done | sort) "${EXTRAS[@]}"; do
    [ ${#ONLY[@]} -eq 0 ] || in_list "$(svc_name "$f")" "${ONLY[@]}" && echo "$f"
  done
}
for o in "${ONLY[@]}"; do
  for f in $(for s in "${SERVICES[@]}"; do service_script "$s"; done) "${EXTRAS[@]}"; do [ "$(svc_name "$f")" = "$o" ] && continue 2; done
  die "--only $o: not a service of this installation (bundles/EXCLUDE/extras)"
done

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
if [ "$RENDER" != 1 ] && [ ${#ONLY[@]} -eq 0 ]; then
  step "Packages"; pkg_install curl git envsubst python3; ok "curl, git, envsubst, python3"
  docker_ensure
  skipped layout || layout_create "${RESOLVED[@]}"
fi

# ---------- secrets ----------
step "Secrets"
[ "$HS_DRY_RUN" = 1 ] || [ "${HS_SECRETS_RO:-0}" = 1 ] || mkdir -p "$APPDATA"
if [ -n "${ADMIN_PASSWORD:-}" ] && [ "$HS_DRY_RUN" != 1 ] && [ "${HS_SECRETS_RO:-0}" != 1 ]; then env_set "$(secrets_file)" ADMIN_PASSWORD "$ADMIN_PASSWORD"; fi
secret_ensure ADMIN_PASSWORD 20
for s in "${SERVICES[@]}"; do   # API keys the *arr apps are started with, so wiring never has to scrape them
  case "$s" in radarr|sonarr|prowlarr|bazarr|lidarr) secret_ensure "$(echo "$s" | tr a-z A-Z)_API_KEY" 32 hex ;; esac
  case "$s" in dockhand) secret_ensure DOCKHAND_ENCRYPTION_KEY 44 ;; speedtest-tracker) secret_ensure SPEEDTEST_KEY_SEED 32 ;;
    paperless) secret_ensure PAPERLESS_DB_PASSWORD 32; secret_ensure PAPERLESS_SECRET_KEY 50 ;; immich-db) secret_ensure IMMICH_DB_PASSWORD 32 ;;
    romm-db) secret_ensure ROMM_DB_PASSWORD 32; secret_ensure ROMM_DB_ROOT_PASSWORD 32 ;; romm) secret_ensure ROMM_AUTH_SECRET_KEY 64 hex ;;
    duplicati) secret_ensure DUPLICATI_SETTINGS_KEY 32 ;; esac
done
env_load "$(secrets_file)"; set -a; env_load "$(secrets_file)"; set +a
ok "secrets in $(secrets_file)"

# ---------- services (in script-number order, then the profile's extras) ----------
if [ "$RENDER" = 1 ]; then
  for f in $(svc_files); do echo "# $f" >&3; HS_RENDER=1 bash "$f" >/dev/null || die "render failed: $f"; done
  exit 0
fi
step "Services"
docker network inspect homelab >/dev/null 2>&1 || run docker network create homelab >/dev/null
pending=()
for f in $(svc_files); do
  n=$(svc_name "$f")
  if bash "$f" >/dev/null; then ok "$n"; else warn "$n failed to start (see: docker logs $n)"; fi
done
for s in "${SERVICES[@]}"; do [ -n "$(service_script "$s")" ] || pending+=("$s"); done
[ ${#pending[@]} -eq 0 ] || warn "not available in this version yet: ${pending[*]}"
[ ${#ONLY[@]} -eq 0 ] || exit 0

# ---------- wiring ----------
skipped wiring && SERVICES_WIRE=() || SERVICES_WIRE=("${SERVICES[@]}")
step "Wiring apps together"
export HS_SERVICES="${SERVICES[*]}" PYTHONPATH="$HS_ROOT/lib"
for s in "${SERVICES_WIRE[@]}"; do
  if [ -f "$HS_ROOT/wire/$s.py" ]; then w=(python3 "$HS_ROOT/wire/$s.py"); elif [ -f "$HS_ROOT/wire/$s.sh" ]; then w=(bash "$HS_ROOT/wire/$s.sh"); else continue; fi
  if [ "$HS_DRY_RUN" = 1 ]; then info "[dry-run] would wire $s"; continue; fi
  if "${w[@]}"; then ok "$s"; else warn "wiring $s failed — re-run install.sh to retry"; fi
done
set -a; env_load "$(secrets_file)"; set +a   # keys created during wiring (Jellyfin, Seerr) for the dashboard

# ---------- dashboard + summary ----------
. "$HS_ROOT/lib/finish.sh"
skipped dashboard || { homepage_render "${SERVICES[@]}"; next_steps_render "${SERVICES[@]}"; }
skipped summary || summary_write "${SERVICES[@]}"
