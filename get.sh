#!/usr/bin/env bash
# One-line installer:  curl -fsSL https://raw.githubusercontent.com/eoin18/homelab-starter/main/get.sh | sudo bash
# Installs git, clones (or updates) the repo into /opt/homelab-starter and runs install.sh.
set -euo pipefail
REPO="${HS_REPO:-https://github.com/eoin18/homelab-starter.git}"
DIR="${HS_DIR:-/opt/homelab-starter}"
[ "$(id -u)" -eq 0 ] || { echo "Please run with sudo"; exit 1; }
if ! command -v git >/dev/null; then
  for m in apt-get dnf pacman zypper; do command -v $m >/dev/null && break; done
  case $m in apt-get) apt-get update -qq && apt-get install -y -qq git ;; dnf) dnf install -y -q git ;;
             pacman) pacman -Sy --noconfirm git ;; zypper) zypper -n install git ;; esac
fi
if [ -d "$DIR/.git" ]; then git -C "$DIR" pull -q --ff-only; else git clone -q --depth 1 "$REPO" "$DIR"; fi
# Re-attach the keyboard: with `curl | bash`, stdin is the script, not the terminal.
if [ -r /dev/tty ]; then exec bash "$DIR/install.sh" "$@" </dev/tty; else exec bash "$DIR/install.sh" "$@"; fi
