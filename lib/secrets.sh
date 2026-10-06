#!/usr/bin/env bash
# Generated secrets live in $APPDATA/.secrets.env (600). Existing values are never replaced.

secrets_file() { echo "$APPDATA/.secrets.env"; }
# Read fixed-size chunks so no pipe is closed early (safe under `set -o pipefail`).
_gen() { local set="$1" n="$2" s=""; while [ ${#s} -lt "$n" ]; do s+=$(head -c 256 /dev/urandom | LC_ALL=C tr -dc "$set"); done; printf '%s' "${s:0:$n}"; }
gen_secret() { _gen 'A-Za-z0-9' "${1:-32}"; }
gen_hex() { _gen 'a-f0-9' "${1:-32}"; }

# secret_ensure VAR [length] [hex]: keep the existing value, else generate and persist
secret_ensure() {
  local var="$1" len="${2:-32}" kind="${3:-alnum}" f; f=$(secrets_file)
  env_load "$f"
  if [ -z "${!var:-}" ]; then
    local v; [ "$kind" = hex ] && v=$(gen_hex "$len") || v=$(gen_secret "$len")
    [ "$HS_DRY_RUN" = 1 ] || env_set "$f" "$var" "$v"
    printf -v "$var" '%s' "$v"; export "${var?}"
  fi
}
