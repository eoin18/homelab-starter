#!/usr/bin/env python3
"""`docker run` commands as data: parse, apply profile overrides, reconstruct from a live container, compare.

A run command is reduced to a Spec: flags keyed by what they configure (env by name, volumes by container path,
ports by container port, labels by key, ...), plus image and command. Two commands are "the same" when their Specs
are equal, regardless of flag order or spelling. Overrides and capture are inverses on Specs, so a profile captured
from a live server renders back to exactly that server.

Override file  <profile>/overrides/<service>.args  (one directive per line, `#` comments, ${VAR} expanded from env, $$ = $):
  -e KEY=value / -v src:dst / -p 8080:80 / --label k=v / --network x ...   set (replaces the flag with the same key)
  unset -e KEY / unset -p 80 / unset --privileged ...                        remove the catalogue's flag
  image repo/name:tag                                                        replace the image
  cmd arg arg ...    /   cmd -                                               replace the command (- = none)

CLI (used by lib/service.sh and tools/profile.py):
  runspec.py apply <docker run argv...>     -> NUL-separated argv with overrides from $HS_PROFILE applied
  runspec.py live <container>               -> shell command reconstructed from `docker inspect`
"""
import json, os, re, shlex, subprocess, sys

# flags that take a value; the key function says which part identifies "the same setting"
def _env_key(v): return v.split('=', 1)[0]
def _vol_key(v): return v.split(':')[1] if ':' in v else v
def _port_key(v):
    p, _, proto = v.partition('/')
    return p.rsplit(':', 1)[-1] + '/' + (proto or 'tcp')
def _kv_key(v): return v.split('=', 1)[0]
def _dev_key(v): parts = v.split(':'); return parts[1] if len(parts) > 1 else parts[0]
def _host_key(v): return re.split('[:=]', v, 1)[0]
def _self(v): return v
MULTI = {'-e': _env_key, '-v': _vol_key, '-p': _port_key, '--label': _kv_key, '--device': _dev_key, '--add-host': _host_key,
         '--cap-add': _self, '--cap-drop': _self, '--security-opt': _self, '--log-opt': _kv_key, '--tmpfs': _vol_key,
         '--sysctl': _kv_key, '--ulimit': _kv_key, '--group-add': _self, '--dns': _self, '--mount': _self}
SINGLE = {'--name', '--restart', '--network', '--user', '--shm-size', '--log-driver', '--hostname', '--entrypoint', '--workdir',
          '--memory', '--cpus', '--pid', '--ipc', '--stop-timeout', '--stop-signal', '--health-cmd', '--health-interval',
          '--health-timeout', '--health-retries', '--health-start-period', '--runtime', '--gpus', '--platform', '--pull'}
BOOL = {'-d', '--detach', '--privileged', '--init', '--rm', '-i', '-t', '-it', '--read-only', '--no-healthcheck'}
ALIAS = {'--env': '-e', '--volume': '-v', '--publish': '-p', '-l': '--label', '--net': '--network', '-u': '--user',
         '-h': '--hostname', '-w': '--workdir', '-m': '--memory', '--detach': '-d'}
IGNORE = {'-d', '--pull'}   # no effect on the resulting container's configuration


class Spec:
    def __init__(self):
        self.flags = {}       # (flag, key) -> value ; bool flags -> True
        self.image = None
        self.cmd = []

    @classmethod
    def parse(cls, argv):
        """argv after `docker run` (a leading 'run' is skipped)."""
        s = cls(); a = list(argv)
        if a and a[0] == 'run': a = a[1:]
        i = 0
        while i < len(a):
            t = a[i]
            if not t.startswith('-'):
                s.image = t; s.cmd = a[i + 1:]; break
            f, eq, inline = t.partition('=') if t.startswith('--') else (t, '', '')
            f = ALIAS.get(f, f)
            if f in BOOL:
                s.flags[(f, '')] = True; i += 1; continue
            if f not in MULTI and f not in SINGLE: raise ValueError(f'unknown docker run flag {t}')
            v = inline if eq else a[i + 1]
            i += 1 if eq else 2
            s.set(f, v)
        return s

    def set(self, f, v):
        f = ALIAS.get(f, f)
        if f in BOOL: self.flags[(f, '')] = True
        elif f in MULTI: self.flags[(f, MULTI[f](v))] = v
        else: self.flags[(f, '')] = v

    def unset(self, f, key=''):
        f = ALIAS.get(f, f)
        if f in MULTI and key: key = MULTI[f](key) if f in ('-p',) else key
        self.flags.pop((f, key), None)

    def norm(self):
        """Comparable form: drops flags with no effect on the container."""
        fl = {k: _normval(k[0], v) for k, v in self.flags.items() if k[0] not in IGNORE}
        return fl, self.image, list(self.cmd)

    def items(self):
        """[(flag, value or True)] in a stable, readable order."""
        order = ['-d', '--name', '--restart', '--network']
        keys = sorted(self.flags, key=lambda k: (order.index(k[0]) if k[0] in order else len(order), k[0], k[1]))
        return [(f, self.flags[(f, k)]) for f, k in keys]

    def argv(self):
        out = ['run']
        for f, v in self.items(): out += [f] if v is True else [f, v]
        return out + [self.image] + self.cmd

    def name(self): return self.flags.get(('--name', ''))


def _normval(f, v):
    if f == '-v':   # docker reports default propagation/rw implicitly
        parts = v.split(':')
        if len(parts) == 3:
            opts = [o for o in parts[2].split(',') if o not in ('rw', 'rprivate')]
            return ':'.join(parts[:2] + ([','.join(sorted(opts))] if opts else []))
    if f == '-p' and '/' not in v: return v + '/tcp'
    if f == '--security-opt': return v.replace('apparmor:', 'apparmor=', 1)
    if f == '--health-cmd': return v.strip()
    return v


# ---------- overrides ----------
def _expand(s):   # ${VAR} / $VAR from the environment; $$ is a literal $
    return re.sub(r'\$\$|\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)',
                  lambda m: '$' if m.group(0) == '$$' else os.environ.get(m.group(1) or m.group(2), ''), s)

def apply_overrides(spec, path):
    if not os.path.exists(path): return spec
    for line in open(path):
        line = line.strip()
        if not line or line.startswith('#'): continue
        toks = [_expand(t) for t in shlex.split(line, comments=True)]
        if not toks: continue
        if toks[0] == 'image': spec.image = toks[1]
        elif toks[0] == 'cmd': spec.cmd = [] if toks[1:] == ['-'] else toks[1:]
        elif toks[0] == 'unset': spec.unset(toks[1], toks[2] if len(toks) > 2 else '')
        else:
            i = 0
            while i < len(toks):
                f = ALIAS.get(toks[i], toks[i])
                if f in BOOL: spec.set(f, True); i += 1
                else: spec.set(f, toks[i + 1]); i += 2
    return spec


def diff_to_overrides(base, live, subst=lambda f, v: v):
    """Override lines that turn `base` into `live` (subst(flag, value) may replace secrets with ${VAR})."""
    b, l = base.norm(), live.norm()
    lines = []
    if b[1] != l[1]: lines.append(f'image {l[1]}')
    if b[2] != l[2]: lines.append('cmd ' + (' '.join(shlex.quote(x) for x in l[2]) if l[2] else '-'))
    for k in sorted(set(b[0]) | set(l[0])):
        if k in l[0] and b[0].get(k) != l[0][k]:
            v = live.flags[k]
            lines.append(k[0] if v is True else f'{k[0]} {_q(subst(k[0], v))}')
        elif k not in l[0]:
            lines.append(f'unset {k[0]}' + (f' {_q(k[1])}' if k[1] else ''))
    return lines

def _q(v):
    """shell-quote but keep ${VAR} expandable by apply_overrides (it expands after shlex)."""
    return shlex.quote(v)


# ---------- live containers ----------
DEFAULT_CAPS = {'CAP_AUDIT_WRITE', 'CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FOWNER', 'CAP_FSETID', 'CAP_KILL', 'CAP_MKNOD',
                'CAP_NET_BIND_SERVICE', 'CAP_NET_RAW', 'CAP_SETFCAP', 'CAP_SETGID', 'CAP_SETPCAP', 'CAP_SETUID', 'CAP_SYS_CHROOT'}

def _inspect(x): return json.loads(subprocess.check_output(['docker', 'inspect', x], stderr=subprocess.DEVNULL))[0]

def from_container(name):
    c = _inspect(name); hc = c['HostConfig']; cfg = c['Config']
    try: img = _inspect(c['Image'])['Config']
    except Exception: img = {}
    s = Spec(); s.set('-d', True); s.set('--name', name)
    rp = hc['RestartPolicy']['Name']
    if rp and rp != 'no': s.set('--restart', rp if rp != 'on-failure' or not hc['RestartPolicy'].get('MaximumRetryCount') else f"on-failure:{hc['RestartPolicy']['MaximumRetryCount']}")
    nm = hc['NetworkMode']
    if nm.startswith('container:'):   # docker stores the id; scripts name the container
        try: nm = 'container:' + _inspect(nm[10:])['Name'].lstrip('/')
        except Exception: pass
    if nm not in ('default', 'bridge'): s.set('--network', nm)
    for h in hc.get('ExtraHosts') or []: s.set('--add-host', h)
    hcfg = cfg.get('Healthcheck')
    if hcfg and hcfg != img.get('Healthcheck') and hcfg.get('Test'):
        t = hcfg['Test']
        if t[0] == 'NONE': s.set('--no-healthcheck', True)
        else:
            s.set('--health-cmd', t[1] if t[0] == 'CMD-SHELL' else ' '.join(t[1:]))
            for k, f in (('Interval', '--health-interval'), ('Timeout', '--health-timeout'), ('StartPeriod', '--health-start-period')):
                if hcfg.get(k): s.set(f, f"{hcfg[k] // 1000000000}s")
            if hcfg.get('Retries'): s.set('--health-retries', str(hcfg['Retries']))
    if hc.get('Privileged'): s.set('--privileged', True)
    if hc.get('Init'): s.set('--init', True)
    for o in hc.get('SecurityOpt') or []: s.set('--security-opt', o.replace('apparmor:', 'apparmor=', 1))
    lc = hc.get('LogConfig') or {}
    if lc.get('Type') and lc['Type'] != 'json-file': s.set('--log-driver', lc['Type'])
    for k, v in (lc.get('Config') or {}).items(): s.set('--log-opt', f'{k}={v}')
    ilab = img.get('Labels') or {}
    for k, v in (cfg.get('Labels') or {}).items():
        if not k.startswith('com.docker.compose') and ilab.get(k) != v: s.set('--label', f'{k}={v}')
    for x in hc.get('CapAdd') or []:
        x = x if x.startswith('CAP_') else 'CAP_' + x
        if x not in DEFAULT_CAPS: s.set('--cap-add', x[4:])
    for x in hc.get('CapDrop') or []: s.set('--cap-drop', x[4:] if x.startswith('CAP_') else x)
    if cfg.get('User') and cfg.get('User') != img.get('User'): s.set('--user', cfg['User'])
    for p, bs in (hc.get('PortBindings') or {}).items():
        for b in bs or []:
            cp = p if not p.endswith('/tcp') else p[:-4]
            s.set('-p', f"{b['HostIp'] + ':' if b.get('HostIp') else ''}{b['HostPort']}:{cp}")
    for d in hc.get('Devices') or []:
        s.set('--device', d['PathOnHost'] + ':' + d['PathInContainer'] + ('' if d.get('CgroupPermissions') in (None, '', 'rwm') else ':' + d['CgroupPermissions']))
    if (hc.get('ShmSize') or 0) not in (0, 67108864): s.set('--shm-size', f"{hc['ShmSize'] // 1048576}m")
    for g in hc.get('GroupAdd') or []: s.set('--group-add', g)
    for m in c['Mounts']:
        src = m['Name'] if m['Type'] == 'volume' else m['Source']
        if m['Type'] == 'volume' and re.fullmatch(r'[0-9a-f]{64}', src or ''): continue   # anonymous volume from the image
        if m['Type'] == 'tmpfs': s.set('--tmpfs', m['Destination']); continue
        opts = [] if m.get('RW', True) else ['ro']
        if m.get('Propagation') and m['Propagation'] != 'rprivate': opts.append(m['Propagation'])
        s.set('-v', f"{src}:{m['Destination']}" + (':' + ','.join(opts) if opts else ''))
    ienv = set(img.get('Env') or [])
    for e in cfg.get('Env') or []:
        if e not in ienv: s.set('-e', e)
    s.image = cfg['Image']
    if cfg.get('Entrypoint') and cfg.get('Entrypoint') != img.get('Entrypoint'): s.set('--entrypoint', ' '.join(cfg['Entrypoint']))
    if cfg.get('Cmd') and cfg.get('Cmd') != img.get('Cmd'): s.cmd = list(cfg['Cmd'])
    return s


def shell(argv): return 'docker ' + ' '.join(shlex.quote(x) for x in argv)


if __name__ == '__main__':
    op, args = sys.argv[1], sys.argv[2:]
    if op == 'apply':
        spec = Spec.parse(args)
        prof = os.environ.get('HS_PROFILE')
        if prof and os.environ.get('HS_NO_OVERRIDES') != '1':
            apply_overrides(spec, os.path.join(prof, 'overrides', f'{spec.name()}.args'))
        sys.stdout.write('\0'.join(spec.argv()) + '\0')
    elif op == 'live':
        for n in args: print(shell(from_container(n).argv()))
    else:
        sys.exit(__doc__)
