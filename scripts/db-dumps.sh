#!/usr/bin/env bash
# Nightly database dumps into $APPDATA/_dumps, so file backups (Duplicati) capture a consistent copy instead of
# live database files. Installed as /etc/cron.d/homelab-starter by the Backup bundle; safe to run by hand.
set -u
HS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
set -a; . "$HS_ROOT/config.env"; APPDATA="${APPDATA:-/srv/appdata}"; . "$APPDATA/.secrets.env"; set +a
OUT="$APPDATA/_dumps"; mkdir -p "$OUT"; chmod 700 "$OUT"; fail=0
running() { [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = true ]; }
dump() {   # dump <name> <command...>: write <name>.gz atomically, keep the previous one on failure
  if "${@:2}" | gzip > "$OUT/$1.tmp" && [ "${PIPESTATUS[0]}" = 0 ]; then mv "$OUT/$1.tmp" "$OUT/$1.gz"; else rm -f "$OUT/$1.tmp"; echo "dump $1 FAILED" >&2; fail=1; fi
}
running paperless-db && dump paperless.sql docker exec paperless-db pg_dumpall -U paperless
running immich-db    && dump immich.sql    docker exec immich-db pg_dumpall -U postgres
running romm-db      && dump romm.sql      docker exec -e MYSQL_PWD="${ROMM_DB_ROOT_PASSWORD:-}" romm-db mariadb-dump -uroot --all-databases --single-transaction
if [ -f "$APPDATA/vaultwarden/db.sqlite3" ]; then
  docker run --rm --user 0 -v "$APPDATA/vaultwarden:/d" -v "$OUT:/o" keinos/sqlite3:latest sqlite3 /d/db.sqlite3 ".backup /o/vaultwarden.sqlite3" || { echo "dump vaultwarden FAILED" >&2; fail=1; }
fi
exit $fail
