#!/usr/bin/env bash
# Shared helpers: logging, errors, config/secret persistence, waiting, idempotency markers.

HS_ROOT="${HS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HS_CONFIG="${HS_CONFIG:-$HS_ROOT/config.env}"
HS_DRY_RUN="${HS_DRY_RUN:-0}"

if [ -t 1 ]; then C_B=$'\e[1m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_R=$'\e[31m'; C_0=$'\e[0m'; else C_B=; C_G=; C_Y=; C_R=; C_0=; fi
step() { echo; echo "${C_B}==> $*${C_0}"; }
info() { echo "    $*"; }
ok()   { echo "    ${C_G}✓${C_0} $*"; }
warn() { echo "    ${C_Y}!${C_0} $*" >&2; }
die()  { echo "${C_R}✗ $*${C_0}" >&2; exit 1; }

# run <cmd...>: execute, or just print it in dry-run mode
run() { if [ "$HS_DRY_RUN" = 1 ]; then echo "    [dry-run] $*"; else "$@"; fi; }

require_root() { [ "$(id -u)" -eq 0 ] || die "run as root (sudo)"; }

# Persist KEY=VALUE into an env file (created 600), replacing an existing key. Values are single-quoted.
env_set() {
  local file="$1" key="$2" val="$3"
  [ -f "$file" ] || { install -m 600 /dev/null "$file"; }
  local esc=${val//\'/\'\\\'\'}
  if grep -q "^${key}=" "$file"; then
    local tmp; tmp=$(mktemp); grep -v "^${key}=" "$file" > "$tmp"; cat "$tmp" > "$file"; rm -f "$tmp"
  fi
  printf "%s='%s'\n" "$key" "$esc" >> "$file"
}
env_load() { [ -f "$1" ] && { set -a; . "$1"; set +a; }; return 0; }

# wait_for_http <url> [timeout-seconds]: success once the URL answers with any HTTP status below 500
wait_for_http() {
  local url="$1" t="${2:-180}" i=0 code
  while [ "$i" -lt "$t" ]; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || true)
    case "$code" in 2*|3*|401|403|404) return 0;; esac
    sleep 2; i=$((i+2))
  done
  return 1
}

# Idempotency markers for one-time steps (e.g. wiring): marker_done <name> / marker_set <name>
marker_dir() { echo "${APPDATA:-/srv/appdata}/.homelab-starter"; }
marker_done() { [ -f "$(marker_dir)/$1.done" ]; }
marker_set() { mkdir -p "$(marker_dir)"; date -Is > "$(marker_dir)/$1.done"; }

# Word-list helpers
in_list() { local x="$1"; shift; for y in "$@"; do [ "$x" = "$y" ] && return 0; done; return 1; }

# ---------- "Finish setup" page: manual steps the installer could not do itself ----------
# todo_add <id> <title> <html body>   (wire scripts call this when an automatic step fails or needs a human)
todo_dir() { echo "$(marker_dir)/todo"; }
todo_add() { [ "${HS_DRY_RUN:-0}" = 1 ] && return 0; mkdir -p "$(todo_dir)"; { echo "$2"; echo "$3"; } > "$(todo_dir)/$1.html"; }
todo_clear() { rm -f "$(todo_dir)/$1.html"; }
