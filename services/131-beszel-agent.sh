#!/usr/bin/env bash
# hs-name: Beszel agent
# hs-group: Monitoring
# Trusts the hub's public key, derived from the hub's own key file (created on the hub's first start).
source "$HS_ROOT/lib/service.sh"
KEYFILE="$APPDATA/beszel/data/id_ed25519"
if [ "${HS_DRY_RUN:-0}" != 1 ]; then
  for _ in $(seq 1 60); do [ -s "$KEYFILE" ] && break; sleep 1; done
  [ -s "$KEYFILE" ] || { echo "beszel hub key not found ($KEYFILE)" >&2; exit 1; }
  BESZEL_AGENT_KEY=$(ssh-keygen -y -f "$KEYFILE")
fi
EXTRA=()   # chart every separate data disk as well as /
for _r in "${DATA_MOVIES:-}" "${DATA_TV:-}" "${DATA_BOOKS:-}" "${DATA_ROMS:-}" "${DATA_PHOTOS:-}" "${DATA_MUSIC:-}"; do
  [ -n "$_r" ] && [ -d "$_r" ] && EXTRA+=(-v "$_r:/extra-filesystems/$(basename "$_r"):ro")
done
recreate beszel-agent
docker run -d --name beszel-agent "${HS_COMMON[@]}" \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v "$APPDATA/beszel/socket:/beszel_socket" \
  -v "$APPDATA/beszel/agent:/var/lib/beszel-agent" \
  "${EXTRA[@]}" \
  -e LISTEN=/beszel_socket/beszel.sock \
  -e KEY="${BESZEL_AGENT_KEY:-dry-run}" \
  henrygd/beszel-agent:latest
