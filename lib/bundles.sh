#!/usr/bin/env bash
# Bundle metadata + dependency resolution. Bundles live in bundles/<id>.conf.

bundle_ids() {  # all bundle ids, menu order
  for f in "$HS_ROOT"/bundles/*.conf; do
    ( . "$f"; echo "$BUNDLE_ORDER $(basename "$f" .conf)" )
  done | sort -n | awk '{print $2}'
}
bundle_get() { ( . "$HS_ROOT/bundles/$1.conf" 2>/dev/null || exit 1; eval "echo \"\${BUNDLE_$2}\"" ); }

# bundles_resolve <id...>: the closure over BUNDLE_DEPENDS (core always), in menu order
bundles_resolve() {
  local -A want=(); local queue=(core "$@") b d
  while [ ${#queue[@]} -gt 0 ]; do
    b="${queue[0]}"; queue=("${queue[@]:1}")
    [ -f "$HS_ROOT/bundles/$b.conf" ] || die "unknown bundle '$b' (see bundles/)"
    [ -n "${want[$b]:-}" ] && continue
    want[$b]=1
    for d in $(bundle_get "$b" DEPENDS); do queue+=("$d"); done
  done
  for b in $(bundle_ids); do [ -n "${want[$b]:-}" ] && echo "$b"; done
}
bundles_services() { local b; for b in "$@"; do bundle_get "$b" SERVICES; done | tr ' ' '\n' | awk 'NF && !s[$0]++'; }
bundles_ram_mb() { local b t=0; for b in "$@"; do t=$((t + $(bundle_get "$b" RAM_MB))); done; echo "$t"; }
