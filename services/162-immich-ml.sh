#!/usr/bin/env bash
# hs-name: Immich face + object recognition
# hs-group: Personal
# Intel iGPU (OpenVINO) build when a GPU was detected, otherwise the CPU build.
source "$HS_ROOT/lib/service.sh"
GPU_ARGS=(); [ "${GPU:-none}" = yes ] && GPU_ARGS=(--device /dev/dri:/dev/dri --group-add "$(stat -c %g /dev/dri/renderD128 2>/dev/null || echo video)")
TAG=v3; [ "${GPU:-none}" = yes ] && TAG=v3-openvino
docker network inspect immich >/dev/null 2>&1 || docker network create immich >/dev/null
recreate immich-ml
docker run -d --name immich-ml "${HS_COMMON[@]}" --network immich "${GPU_ARGS[@]}" \
  -v "$APPDATA/immich/model-cache:/cache" \
  ghcr.io/immich-app/immich-machine-learning:$TAG
