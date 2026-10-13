#!/usr/bin/env bash
# hs-name: Shelfmark (book requests)
# hs-url: http://HOST:8084
# hs-group: Books
# Search and request books; downloads land in $DATA_BOOKS/ingest for Calibre-Web to import. Logs in with Calibre-Web's users.
source "$HS_ROOT/lib/service.sh"
recreate shelfmark
docker run -d --name shelfmark "${HS_COMMON[@]}" "${HS_IDS[@]}" \
  -p 8084:8084 \
  -v "$APPDATA/shelfmark:/config" \
  -v "$DATA_BOOKS/ingest:/books" \
  -v "$APPDATA/cwa/config/app.db:/auth/app.db:ro" \
  ghcr.io/calibrain/shelfmark:latest
