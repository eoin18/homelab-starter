#!/usr/bin/env bash
# Dockhand: register the local Docker environment, safe auto-update defaults, admin login, and enrol every container.
# Dockhand keeps all of this in its SQLite DB (no API for first-run setup), so this writes the same rows its UI writes,
# with Dockhand stopped, via a throwaway sqlite3 container. Anything that fails becomes a "Finish setup" step.
#   - per-container auto-update rows: daily 04:30, vulnerability gate "more_than_current" (blocks only regressions)
#   - environment-level update check: notify only (auto-apply OFF — it races the per-container schedules)
#   - image prune: weekly, dangling only ("all unused" would delete locally built images)
#   - skipped: dockhand itself, containers labelled dockhand.update=false, digest-pinned images (update those deliberately)
set -eu
. "$HS_ROOT/lib/common.sh"
DB_DIR="$APPDATA/dockhand/db"; DB=dockhand.db
SQLITE=(docker run --rm --user 0 -v "$DB_DIR:/db" keinos/sqlite3:latest sqlite3 "/db/$DB")
q() { "${SQLITE[@]}" "$1"; }

for _ in $(seq 1 60); do [ -s "$DB_DIR/$DB" ] && q "select count(*) from roles" >/dev/null 2>&1 && break; sleep 2; done
if ! q "select count(*) from roles" >/dev/null 2>&1; then
  todo_add dockhand-setup "Set up Dockhand" "Open <a href=\"http://HOST:3010\">Dockhand</a>: Settings &rarr; Environments &rarr; add <i>Local socket</i> (<code>/var/run/docker.sock</code>); Settings &rarr; Authentication &rarr; enable login; then enable auto-update on each container (Settings tab), daily 04:30, vulnerability criteria <i>More than current</i>."
  exit 0
fi

ENROL=$(docker ps --format '{{.Names}}' | while read -r c; do
  [ "$c" = dockhand ] && continue
  [ "$(docker inspect -f '{{index .Config.Labels "dockhand.update"}}' "$c")" = false ] && continue
  case "$(docker inspect -f '{{.Config.Image}}' "$c")" in *@sha256:*) continue ;; esac
  echo "$c"
done)

HASH=""
if ! marker_done dockhand-login; then
  HASH=$(printf '%s' "$ADMIN_PASSWORD" | docker run --rm -i alpine:3 sh -c 'apk add -q argon2 >/dev/null 2>&1 && argon2 "$(head -c 16 /dev/urandom | base64)" -id -t 3 -m 16 -p 4 -e' 2>/dev/null || true)
fi

SQL=$(mktemp); trap 'rm -f "$SQL"' EXIT
{
  echo "BEGIN;"
  echo "INSERT INTO environments (name, connection_type, socket_path) SELECT '$(hostname)', 'socket', '/var/run/docker.sock' WHERE NOT EXISTS (SELECT 1 FROM environments);"
  echo "CREATE TEMP TABLE e AS SELECT min(id) AS id FROM environments;"
  for kv in "update_check|{\"enabled\":true,\"cron\":\"30 4 * * *\",\"autoUpdate\":false,\"vulnerabilityCriteria\":\"more_than_current\"}" \
            "image_prune|{\"enabled\":true,\"cronExpression\":\"0 3 * * 0\",\"pruneMode\":\"dangling\"}" \
            "timezone|\"$TZ\"" "vulnerability_scanner|\"both\""; do
    k=${kv%%|*}; v=${kv#*|}
    echo "INSERT OR IGNORE INTO settings (key, value) SELECT 'env_'||id||'_$k', '$v' FROM e;"
  done
  for c in $ENROL; do
    echo "INSERT INTO auto_update_settings (environment_id, container_name, enabled, schedule_type, cron_expression, vulnerability_criteria) SELECT id, '$c', 1, 'daily', '30 4 * * *', 'more_than_current' FROM e WHERE NOT EXISTS (SELECT 1 FROM auto_update_settings WHERE container_name='$c');"
  done
  if [ -n "$HASH" ]; then
    echo "INSERT INTO users (username, password_hash, display_name) SELECT '$ADMIN_USER', '$HASH', '$ADMIN_USER' WHERE NOT EXISTS (SELECT 1 FROM users);"
    echo "INSERT INTO user_roles (user_id, role_id) SELECT u.id, r.id FROM users u, roles r WHERE u.username='$ADMIN_USER' AND r.name='Admin' AND NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id=u.id);"
    echo "INSERT OR IGNORE INTO auth_settings (id) VALUES (1);"
    echo "UPDATE auth_settings SET auth_enabled=1 WHERE id=1 AND EXISTS (SELECT 1 FROM users u JOIN user_roles ur ON ur.user_id=u.id);"
  fi
  echo "COMMIT;"
} > "$SQL"

docker stop dockhand >/dev/null
if docker run --rm --user 0 -v "$DB_DIR:/db" -v "$SQL:/x.sql:ro" keinos/sqlite3:latest sqlite3 "/db/$DB" ".read /x.sql"; then
  ok "dockhand: $(echo $ENROL | wc -w) container(s) on nightly auto-update"
  if [ -n "$HASH" ] && [ "$(q "select auth_enabled from auth_settings where id=1")" = 1 ]; then
    marker_set dockhand-login; todo_clear dockhand-login; ok "dockhand: login enabled for $ADMIN_USER"
  fi
else
  warn "dockhand: could not write settings"
fi
docker start dockhand >/dev/null
if ! marker_done dockhand-login; then
  todo_add dockhand-login "Switch on Dockhand's login" "Dockhand controls every container, so it should ask for a password. Open <a href=\"http://HOST:3010\">Dockhand</a> &rarr; Settings &rarr; Authentication &rarr; create the admin user and enable authentication."
fi
