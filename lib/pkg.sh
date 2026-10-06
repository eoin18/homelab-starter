#!/usr/bin/env bash
# Package-manager shim: pkg_install <pkg...> using apt, dnf, pacman or zypper.

pkg_manager() {
  for m in apt-get dnf pacman zypper; do command -v "$m" >/dev/null 2>&1 && { echo "$m"; return; }; done
  echo none
}

pkg_install() {
  local missing=() p
  for p in "$@"; do command -v "$p" >/dev/null 2>&1 || missing+=("$(pkg_for "$p")"); done
  [ ${#missing[@]} -eq 0 ] && return 0
  case "$(pkg_manager)" in
    apt-get) run env DEBIAN_FRONTEND=noninteractive apt-get update -qq && run env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}" ;;
    dnf)     run dnf install -y -q "${missing[@]}" ;;
    pacman)  run pacman -Sy --noconfirm --needed "${missing[@]}" ;;
    zypper)  run zypper --non-interactive install "${missing[@]}" ;;
    *)       die "no supported package manager; please install: ${missing[*]}" ;;
  esac
}
# Command name -> package name differences
pkg_for() { case "$1" in envsubst) [ "$(pkg_manager)" = apt-get ] && echo gettext-base || echo gettext;; whiptail) [ "$(pkg_manager)" = dnf ] && echo newt || { [ "$(pkg_manager)" = pacman ] && echo libnewt || echo whiptail; };; *) echo "$1";; esac; }
