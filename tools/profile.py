#!/usr/bin/env python3
"""Keep a profile and a running server in step.

  tools/profile.py diff    --profile DIR      what differs between `install.sh --render --profile DIR` and the live containers
  tools/profile.py capture --profile DIR      make the profile match the live containers:
      catalogue service      -> overrides/<name>.args = the difference between the catalogue command and the live one
      catalogue, not running -> added to EXCLUDE in profile.env
      other live container   -> extras/<name>.sh generated from `docker inspect` (marked unreviewed)
      extras, not running    -> extras/<name>.sh removed
    Secrets: a value equal to one in SECRETS_ENV is written as ${THATVAR}; secret-looking values that are not
    there yet are added to SECRETS_ENV as <SERVICE>_<KEY>. A final scan refuses to leave any secret value in DIR.
    Options: --dry-run (print, change nothing)  --quiet (only print when something changed)
Exit status: diff -> 1 if anything differs; capture -> 2 if a secret would have leaked (nothing written).
"""
import datetime, os, re, shlex, subprocess, sys
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(HERE, 'lib'))
import runspec as R

args = sys.argv[1:]
if not args or args[0] not in ('diff', 'capture') or '--profile' not in args: sys.exit(__doc__)
OP = args[0]; PROF = os.path.abspath(args[args.index('--profile') + 1])
DRY = '--dry-run' in args; QUIET = '--quiet' in args


def read_env(p):
    d = {}
    if p and os.path.exists(p):
        for l in open(p):
            l = l.strip()
            if l and not l.startswith('#') and '=' in l:
                k, v = l.split('=', 1)
                try: v = (shlex.split(v, comments=True) or [''])[0]
                except ValueError: v = v.strip().strip("'\"")
                d[k] = v
    return d

PENV = read_env(os.path.join(PROF, 'profile.env'))
SECRETS_PATH = os.path.expanduser(PENV.get('SECRETS_ENV', '')) or None
SECRETS = read_env(SECRETS_PATH)
IGNORE = set(PENV.get('CAPTURE_IGNORE', '').split())


def render(no_overrides=False):
    """{container: (Spec, script path)} from install.sh --render."""
    env = {**os.environ, **({'HS_NO_OVERRIDES': '1'} if no_overrides else {})}
    r = subprocess.run(['bash', os.path.join(HERE, 'install.sh'), '--render', '--profile', PROF], env=env,
                       capture_output=True, text=True)
    if r.returncode: sys.exit(f'render failed:\n{r.stderr[-2000:]}')
    out, src = {}, None
    for line in r.stdout.splitlines():
        if line.startswith('# '): src = line[2:]; continue
        if line.startswith('docker run'):
            s = R.Spec.parse(shlex.split(line)[1:])
            out[s.name()] = (s, src)
    return out


def live_names():
    return [n for n in subprocess.check_output(['docker', 'ps', '-a', '--format', '{{.Names}}'], text=True).split() if n not in IGNORE]


def describe(a, b):
    """Human list of differences, a = rendered, b = live."""
    (fa, ia, ca), (fb, ib, cb) = a.norm(), b.norm()
    d = []
    if ia != ib: d.append(f'image {ia} -> {ib}')
    if ca != cb: d.append(f'cmd {ca} -> {cb}')
    for k in sorted(set(fa) | set(fb)):
        if fa.get(k) != fb.get(k):
            d.append(f'{k[0]} {k[1]}: {_mask(fa.get(k))} -> {_mask(fb.get(k))}'.replace(' : ', ': '))
    return d

SECRET_VALUES = {v for v in SECRETS.values() if len(v) >= 8}
def _mask(v):
    if v is None or v is True: return {None: '(none)', True: 'on'}[v]
    for s in SECRET_VALUES: v = v.replace(s, '***')
    return v


# ---------- secrets ----------
NAME_SECRET = re.compile(r'(PASS|PASSWD|PASSWORD|SECRET|TOKEN|_KEY$|^KEY$|AUTHORIZATION|API_KEY|ENCRYPTION)', re.I)
by_value, all_by_value = {}, {}
for k, v in SECRETS.items():
    if len(v) >= 6: by_value.setdefault(v, k); all_by_value.setdefault(v, []).append(k)
minted = {}

def best_var(val, svc='', key=''):
    """The secrets.env name for a value; several names can share one value, so prefer the most related name."""
    names = all_by_value.get(val) or ([by_value[val]] if val in by_value else [])
    if not names: return None
    svc_u = re.sub(r'[^A-Z0-9]', '_', svc.upper()).split('_')[0]
    words = [w for w in re.split(r'[^A-Z0-9]', key.upper()) if len(w) > 2 and w not in ('VAR', 'HOMEPAGE', 'KEY', 'API')]
    def score(n):
        return (n == key, n.endswith('_' + key) if key else False, sum(w in n for w in words), n.startswith(svc_u) if svc_u else False, -len(n))
    return max(names, key=score)

def looks_secret(k, v):
    if v.startswith(('http://', 'https://', '/')) or v.lower() in ('true', 'false', 'yes', 'no', '0', '1', ''): return False
    if k.upper().endswith(('_USER', '_USERNAME')): return False
    return len(v) >= 8 and bool(NAME_SECRET.search(k))

def secret_ref(svc, key, val):
    """${VAR} for a known/new secret value, else None."""
    if val in by_value: return '${%s}' % best_var(val, svc, key)
    if looks_secret(key, val):
        var = re.sub(r'[^A-Z0-9]', '_', f'{svc}_{key}'.upper())
        while var in SECRETS and SECRETS[var] != val: var += '_2'
        minted[var] = val; by_value[val] = var; all_by_value[val] = [var]; SECRETS[var] = val
        return '${%s}' % var
    return None

def esc(v): return v.replace('$', '$$')

def subst_value(svc):
    """value transformer for override lines: env values and tokens that are secrets become ${VAR}."""
    def f(flag, v):
        if flag == '-e' and '=' in v:
            k, val = v.split('=', 1); ref = secret_ref(svc, k, val)
            return f'{k}={ref}' if ref else esc(v)
        ref = best_var(v, svc)
        return '${%s}' % ref if ref else esc(v)
    return f


# ---------- override files ----------
def override_lines(svc, base, live):
    lines = R.diff_to_overrides(base, live, subst_value(svc))
    out = []
    for l in lines:   # cmd tokens can be secrets too (cloudflared --token)
        if l.startswith('cmd ') and l != 'cmd -':
            toks = shlex.split(l)[1:]
            l = 'cmd ' + ' '.join(('${%s}' % best_var(t, svc)) if t in by_value else shlex.quote(esc(t)) for t in toks)
        elif l.startswith('image '): l = 'image ' + esc(l[6:])
        out.append(l)
    return out


def extras_script(name, live):
    """bash script recreating `live` (secrets as "${VAR}")."""
    toks = []
    for f, v in live.items():
        if f == '-d': continue
        if v is True: toks.append(f)
        elif f == '-e' and '=' in v: k, val = v.split('=', 1); toks.append(f'{f} ' + _shq(name, k, val, prefix=k + '='))
        else: toks.append(f'{f} ' + _shq(name, '', v))
    toks.append(' '.join([shlex.quote(live.image)] + [_shq(name, '', c) for c in live.cmd]))
    body = ' \\\n  '.join(['docker run -d'] + toks)
    return (f'#!/usr/bin/env bash\n# hs-name: {name}\n# captured from the live container {datetime.date.today()} '
            f'(unreviewed: tidy up, then delete this line)\nsource "$HS_ROOT/lib/service.sh"\nrecreate {name}\n{body}\n')

def _shq(svc, key, val, prefix=''):
    ref = secret_ref(svc, key, val) if key else ('${%s}' % best_var(val, svc) if val in by_value else None)
    if ref: return f'"{prefix}{ref}"'
    return shlex.quote(prefix + val)


# ---------- main ----------
live = {n: R.from_container(n) for n in live_names()}
cur = render()

if OP == 'diff':
    drift = 0
    for n, (s, src) in sorted(cur.items()):
        if n not in live: print(f'{n}: in the profile but not running'); drift += 1; continue
        d = describe(s, live[n])
        if d: drift += 1; print(f'{n}: ' + '\n    '.join([''] + d))
    for n in sorted(set(live) - set(cur)): print(f'{n}: running but not in the profile'); drift += 1
    if drift or not QUIET: print('no drift' if not drift else f'{drift} container(s) differ')
    sys.exit(1 if drift else 0)

# capture
base = render(no_overrides=True)
changes, writes, removes = [], {}, []
ovdir, exdir = os.path.join(PROF, 'overrides'), os.path.join(PROF, 'extras')
exclude = set(PENV.get('EXCLUDE', '').split())
for n, (s, src) in sorted(base.items()):
    is_extra = src and src.startswith(exdir)
    if n not in live:
        if is_extra: removes.append(src); changes.append(f'{n}: no longer running -> extras script removed')
        else: exclude.add(n); changes.append(f'{n}: not running -> added to EXCLUDE')
        continue
    if is_extra:
        if describe(cur[n][0], live[n]):
            writes[src] = extras_script(n, live[n]); changes.append(f'{n}: extras script regenerated')
        continue
    path = os.path.join(ovdir, f'{n}.args')
    lines = override_lines(n, s, live[n])
    text = ('# overrides for ' + n + ' (written by tools/profile.py capture; hand edits are kept only if they match live)\n'
            + '\n'.join(lines) + '\n') if lines else None
    old = open(path).read() if os.path.exists(path) else None
    if text != old:
        if text: writes[path] = text; changes.append(f'{n}: overrides updated ({len(lines)} line(s))')
        else: removes.append(path); changes.append(f'{n}: overrides no longer needed -> removed')
for n in sorted(set(live) - set(base)):
    path = os.path.join(exdir, f'{n}.sh')
    writes[path] = extras_script(n, live[n]); changes.append(f'{n}: new container -> extras/{n}.sh (unreviewed)')
if exclude != set(PENV.get('EXCLUDE', '').split()):
    pe = os.path.join(PROF, 'profile.env'); t = open(pe).read()
    line = f'EXCLUDE="{" ".join(sorted(exclude))}"'
    t = re.sub(r'^EXCLUDE=.*$', line, t, flags=re.M) if re.search(r'^EXCLUDE=', t, re.M) else t.rstrip('\n') + '\n' + line + '\n'
    writes[pe] = t

# leak scan before anything is written
leaks = [p for p, t in writes.items() for v in SECRET_VALUES | set(minted.values()) if v in t]
if leaks: print('REFUSING: a secret value would be written to', sorted(set(leaks))); sys.exit(2)

if changes or not QUIET:
    print('\n'.join(changes) if changes else 'profile already matches the live containers')
    if minted: print('new secrets ->', SECRETS_PATH, ', '.join(sorted(minted)))
if DRY:
    for p, t in writes.items(): print(f'--- {p}\n{t}')
    sys.exit(0)
if minted:
    if not SECRETS_PATH: sys.exit('secrets found but SECRETS_ENV is not set in profile.env')
    with open(SECRETS_PATH, 'a') as fh:
        fh.write(f'\n# added by homelab-starter tools/profile.py capture {datetime.date.today()}\n')
        for k, v in sorted(minted.items()): fh.write(f"{k}='{v}'\n")
for p, t in writes.items():
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w').write(t)
    if p.endswith('.sh'): os.chmod(p, 0o755)
for p in removes: os.remove(p)
