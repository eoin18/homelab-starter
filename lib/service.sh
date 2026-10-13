#!/usr/bin/env bash
# Sourced by services/*.sh. Config + secrets are already exported by install.sh.
set -eu   # no pipefail: a "no match" mid-pipeline (grep, getent, ls) must not abort silently
# `docker run` goes through lib/runspec.py, which applies the profile's overrides/<name>.args (if any).
_hs_run_argv() { HS_RUN_ARGV=(); local x; while IFS= read -r -d '' x; do HS_RUN_ARGV+=("$x"); done < <(python3 "$HS_ROOT/lib/runspec.py" apply "$@"); }
if [ "${HS_RENDER:-0}" = 1 ]; then      # --render: print only the final run commands (fd 3), touch nothing
  docker() { [ "$1" = run ] || return 0; _hs_run_argv "$@"; { printf 'docker'; printf ' %q' "${HS_RUN_ARGV[@]}"; echo; } >&3; }
  recreate() { :; }
elif [ "${HS_DRY_RUN:-0}" = 1 ]; then
  docker() { [ "$1" = run ] && { _hs_run_argv "$@"; set -- "${HS_RUN_ARGV[@]}"; }; printf '    [dry-run] docker'; printf ' %q' "$@"; echo; }
  recreate() { :; }
else
  docker() { if [ "$1" = run ] && [ -n "${HS_PROFILE:-}" ]; then _hs_run_argv "$@"; command docker "${HS_RUN_ARGV[@]}"; else command docker "$@"; fi; }
  recreate() { command docker rm -f "$1" >/dev/null 2>&1 || true; }
fi
# Common flags every container gets
HS_COMMON=(--restart unless-stopped --add-host=host.docker.internal:host-gateway -e TZ="$TZ")

# Data roots mounted at the same path inside every media container (downloads + library must share a mount
# for hardlinks). Per-type overrides outside $DATA get their own mount.
HS_DATA_MOUNTS=(-v "$DATA:$DATA:rslave")
for _r in "${DATA_MOVIES:-}" "${DATA_TV:-}" "${DATA_BOOKS:-}" "${DATA_ROMS:-}" "${DATA_MUSIC:-}"; do
  [ -n "$_r" ] && case "$_r/" in "$DATA"/*) ;; *) HS_DATA_MOUNTS+=(-v "$_r:$_r:rslave") ;; esac
done
HS_IDS=(-e PUID="$PUID" -e PGID="$PGID" -e UMASK=002)

# write_once <file> : stdin → file, only if it does not exist yet (pre-seeding config before first start)
write_once() { [ "${HS_DRY_RUN:-0}" = 1 ] && { cat >/dev/null; return 0; }; [ -e "$1" ] && { cat >/dev/null; return 0; }; mkdir -p "$(dirname "$1")"; cat > "$1"; chown "$PUID:$PGID" "$(dirname "$1")" "$1"; }

# arr_config <dir> <port> <api-key>: Servarr config.xml with a known API key
arr_config() {
  [ "${HS_DRY_RUN:-0}" = 1 ] && return 0
  write_once "$1/config.xml" <<XML
<Config>
  <BindAddress>*</BindAddress>
  <Port>$2</Port>
  <ApiKey>$3</ApiKey>
  <AuthenticationMethod>Forms</AuthenticationMethod>
  <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
  <UpdateMechanism>Docker</UpdateMechanism>
  <LogLevel>info</LogLevel>
</Config>
XML
}
