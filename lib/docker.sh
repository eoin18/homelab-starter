#!/usr/bin/env bash
# Docker Engine: install via Docker's official convenience script when missing.

docker_ensure() {
  step "Docker"
  if ! command -v docker >/dev/null 2>&1; then
    [ "$DET_OS_SUPPORTED" = full ] || die "Docker is not installed and $DET_OS_NAME is not auto-supported. Install Docker Engine, then re-run."
    info "installing Docker Engine (get.docker.com)…"
    run sh -c 'curl -fsSL https://get.docker.com | sh'
  fi
  run systemctl enable --now docker >/dev/null 2>&1 || true
  [ "$HS_DRY_RUN" = 1 ] || docker info >/dev/null 2>&1 || die "Docker is installed but not running"
  run usermod -aG docker "$ADMIN_SYSUSER"
  ok "Docker $( [ "$HS_DRY_RUN" = 1 ] && echo '(dry run)' || docker version --format '{{.Server.Version}}')"
}
