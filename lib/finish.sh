#!/usr/bin/env bash
# Homepage dashboard + summary/CREDENTIALS.txt, driven by "# hs-*" headers in services/*.sh.

svc_meta() { { grep -m1 "^# hs-$2:" "$(service_script "$1")" 2>/dev/null || true; } | sed "s/^# hs-$2: *//"; }

homepage_render() {
  in_list homepage "$@" || return 0
  step "Dashboard"
  local cfg="$APPDATA/homepage/config" s g frag
  [ "$HS_DRY_RUN" = 1 ] && { info "[dry-run] would write $cfg"; return; }
  mkdir -p "$cfg"
  cat > "$cfg/settings.yaml" <<YAML
title: Home server
theme: dark
color: slate
headerStyle: clean
YAML
  printf 'my-docker:\n  socket: /var/run/docker.sock\n' > "$cfg/docker.yaml"
  printf -- '- resources:\n    cpu: true\n    memory: true\n    disk: /\n- search:\n    provider: duckduckgo\n' > "$cfg/widgets.yaml"
  : > "$cfg/bookmarks.yaml"
  local -A groups=(); local order=()
  for s in "$@"; do
    frag="$HS_ROOT/homepage/$s.yaml"; [ -f "$frag" ] && [ -n "$(service_script "$s")" ] || continue
    g=$(svc_meta "$s" group); g=${g:-Other}
    [ -n "${groups[$g]:-}" ] || order+=("$g")
    groups[$g]+="$(HOST_IP="$HOST_IP" envsubst < "$frag")"$'\n'
  done
  { if [ -n "$(ls "$(todo_dir)" 2>/dev/null; for t in "$@"; do [ -f "$HS_ROOT/todo/$t.html" ] && echo x; done)" ]; then
      printf -- '- Finish setup:\n    - Remaining steps:\n        icon: mdi-clipboard-check-outline\n        href: http://%s:3003/\n        description: A few things the installer could not do for you\n' "$HOST_IP"; fi
    for g in "${order[@]}"; do echo "- $g:"; printf '%s' "${groups[$g]}"; done; } > "$cfg/services.yaml"
  chown -R "$PUID:$PGID" "$APPDATA/homepage"
  ok "dashboard at http://$HOST_IP:3000"
}

summary_write() {
  step "Done"
  local f="$APPDATA/CREDENTIALS.txt" s name url
  local lines=("homelab-starter — $(date '+%Y-%m-%d %H:%M')" "" "Admin login for every app:" "  user:     $ADMIN_USER" "  password: $ADMIN_PASSWORD" "" "Apps:")
  for s in "$@"; do
    [ -n "$(service_script "$s")" ] || continue
    name=$(svc_meta "$s" name); url=$(svc_meta "$s" url)
    [ -n "$url" ] && lines+=("  $(printf '%-22s' "${name:-$s}") ${url//HOST/$HOST_IP}")
  done
  lines+=("" "Settings: $HS_CONFIG   Secrets: $(secrets_file)" "Re-run: sudo $HS_ROOT/install.sh   (--reconfigure, --add <bundle>, --status)")
  if [ "$HS_DRY_RUN" != 1 ]; then printf '%s\n' "${lines[@]}" > "$f"; chmod 600 "$f"; fi
  printf '    %s\n' "${lines[@]}"
  echo; if [ "$HS_DRY_RUN" = 1 ]; then info "(dry run: nothing was saved)"; else info "this summary is saved in $f (readable by root only)"; fi
}

# next_steps_render <services...>: HTML page of manual steps (static todo/<svc>.html + todo_add entries) and app links,
# served by Homepage at http://HOST:3000/images/finish-setup.html. Ticks are remembered in the browser.
next_steps_render() {
  in_list welcome "$@" || return 0
  local out="$APPDATA/welcome/index.html" s f items="" apps="" n=0 name url
  [ "$HS_DRY_RUN" = 1 ] && { info "[dry-run] would write $out"; return; }
  mkdir -p "$(dirname "$out")"
  for f in $(for s in "$@"; do [ -f "$HS_ROOT/todo/$s.html" ] && echo "$HS_ROOT/todo/$s.html"; done) $(ls "$(todo_dir)"/*.html 2>/dev/null); do
    n=$((n+1)); items+="<li><label><input type=checkbox data-k=\"$(basename "$f" .html)\"> <b>$(head -1 "$f")</b></label><p>$(tail -n +2 "$f" | sed "s/HOST/$HOST_IP/g")</p></li>"
  done
  for s in "$@"; do name=$(svc_meta "$s" name); url=$(svc_meta "$s" url); [ -n "$url" ] && apps+="<li><a href=\"${url/HOST/$HOST_IP}\">$name</a></li>"; done
  cat > "$out" <<HTML
<!doctype html><html><head><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1"><title>Finish setup</title>
<style>:root{color-scheme:light dark;--bg:#f6f7f9;--fg:#1d2330;--card:#fff;--mut:#5b6474;--acc:#2f6fed}
@media(prefers-color-scheme:dark){:root{--bg:#14171c;--fg:#e6e9ef;--card:#1d2128;--mut:#9aa3b2;--acc:#6f9cff}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif}main{max-width:760px;margin:auto;padding:24px 16px}
h1{font-size:1.5rem}section{background:var(--card);border-radius:12px;padding:16px 20px;margin:16px 0}ol{padding-left:1.2em}li{margin:.6em 0}
li p{margin:.2em 0 0 1.6em;color:var(--mut)}a{color:var(--acc)}code{background:rgba(127,127,127,.15);padding:1px 5px;border-radius:4px}
label input:checked+b{text-decoration:line-through;opacity:.6}</style></head><body><main>
<h1>Finish setting up your home server</h1>
<p>The installer did everything it could. $n step(s) need you — tick them off as you go (remembered in this browser).</p>
<section><h2>Remaining steps</h2><ol>$items</ol></section>
<section><h2>Admin login</h2><p>Every app uses the same admin user: <code>$ADMIN_USER</code>. The password is in
<code>$APPDATA/CREDENTIALS.txt</code> on the server (readable by root: <code>sudo cat $APPDATA/CREDENTIALS.txt</code>).</p></section>
<section><h2>Your apps</h2><ul>$apps</ul></section>
<p style="color:var(--mut)">Bookmark this page: <code>http://$HOST_IP:3003</code>. Generated $(date '+%F %H:%M') by homelab-starter. Re-run the installer to refresh this page.</p></main>
<script>document.querySelectorAll('input[data-k]').forEach(c=>{const k='hs-done-'+c.dataset.k;try{c.checked=localStorage.getItem(k)==='1'}catch(e){}
c.addEventListener('change',()=>{try{localStorage.setItem(k,c.checked?'1':'0')}catch(e){}})})</script></body></html>
HTML
  chown -R "$PUID:$PGID" "$APPDATA/welcome"
  ok "finish-setup page: http://$HOST_IP:3003/ ($n step(s))"
  { [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v xdg-open >/dev/null && sudo -u "${SUDO_USER:-root}" xdg-open "http://$HOST_IP:3003/" >/dev/null 2>&1 & } || true
}
