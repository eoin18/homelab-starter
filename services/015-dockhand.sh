#!/usr/bin/env bash
# hs-name: Dockhand (containers + auto-updates)
# hs-url: http://HOST:3010
# hs-group: System
# Holds the Docker socket (= root on this machine). wire/dockhand.sh enrols every container in nightly auto-updates
# (04:30, vulnerability gate "more than current", dangling-only image prune). Dockhand itself is excluded by label.
source "$HS_ROOT/lib/service.sh"
recreate dockhand
docker run -d --name dockhand "${HS_COMMON[@]}" \
  --label dockhand.update=false \
  -p 3010:3000 \
  -v "$APPDATA/dockhand:/app/data" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e ENCRYPTION_KEY="$DOCKHAND_ENCRYPTION_KEY" \
  fnsys/dockhand:latest
