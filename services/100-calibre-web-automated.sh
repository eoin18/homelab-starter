#!/usr/bin/env bash
# hs-name: Calibre-Web (books)
# hs-url: http://HOST:8083
# hs-group: Books
# Ebook library + reader. Drop books into $DATA_BOOKS/ingest and they are added automatically.
source "$HS_ROOT/lib/service.sh"
recreate calibre-web-automated
docker run -d --name calibre-web-automated "${HS_COMMON[@]}" "${HS_IDS[@]}" \
  -p 8083:8083 \
  -v "$APPDATA/cwa/config:/config" \
  -v "$DATA_BOOKS/library:/calibre-library" \
  -v "$DATA_BOOKS/ingest:/cwa-book-ingest" \
  -e NETWORK_SHARE_MODE=false \
  crocodilestick/calibre-web-automated:latest
