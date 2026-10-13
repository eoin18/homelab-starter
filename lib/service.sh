#!/usr/bin/env bash
# Sourced by services/*.sh. Config + secrets are already exported by install.sh.
set -eu   # no pipefail: a "no match" mid-pipeline (grep, getent, ls) must not abort silently
if [ "${HS_DRY_RUN:-0}" = 1 ]; then
  docker() { printf '    [dry-run] docker'; printf ' %q' "$@"; echo; }
  recreate() { :; }
else
  recreate() { docker rm -f "$1" >/dev/null 2>&1 || true; }
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
write_once() { [ -e "$1" ] && { cat >/dev/null; return 0; }; mkdir -p "$(dirname "$1")"; cat > "$1"; chown "$PUID:$PGID" "$(dirname "$1")" "$1"; }

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
