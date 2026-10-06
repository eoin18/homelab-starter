"""Tiny HTTP/JSON helper for wire/*.py (stdlib only)."""
import http.cookiejar, json, os, ssl, sys, time, urllib.error, urllib.parse, urllib.request

E = os.environ
_ctx = ssl._create_unverified_context()
_jar = http.cookiejar.CookieJar()
_opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(_jar), urllib.request.HTTPSHandler(context=_ctx))

def req(method, url, body=None, headers=None, form=False, timeout=60):
    data = None
    h = dict(headers or {})
    if body is not None:
        if form:
            data = urllib.parse.urlencode(body).encode(); h.setdefault('Content-Type', 'application/x-www-form-urlencoded')
        else:
            data = json.dumps(body).encode(); h.setdefault('Content-Type', 'application/json')
    r = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with _opener.open(r, timeout=timeout) as x:
            t = x.read(); code = x.status
    except urllib.error.HTTPError as e:
        t = e.read(); code = e.code
    try: return code, json.loads(t) if t else None
    except ValueError: return code, t.decode(errors='replace')

def wait(url, timeout=240, ok=(200, 204, 301, 302, 401)):
    end = time.time() + timeout
    while time.time() < end:
        try:
            if req('GET', url, timeout=5)[0] in ok: return True
        except Exception: pass
        time.sleep(3)
    die(f'timed out waiting for {url}')

def die(msg): print(f'      {msg}', file=sys.stderr); sys.exit(1)
def note(msg): print(f'      {msg}')
def installed(service): return service in E.get('HS_SERVICES', '').split()

def save_secret(key, value):
    """Append/replace KEY in $APPDATA/.secrets.env (keys other wiring/Homepage need later)."""
    f = os.path.join(E['APPDATA'], '.secrets.env')
    lines = [l for l in open(f).read().splitlines() if not l.startswith(key + '=')] if os.path.exists(f) else []
    lines.append(f"{key}='{value}'")
    with open(f, 'w') as fh: fh.write('\n'.join(lines) + '\n')
    os.chmod(f, 0o600); os.environ[key] = value

class Arr:
    """Radarr/Sonarr/Prowlarr API (v3 for Radarr/Sonarr, v1 for Prowlarr)."""
    def __init__(self, port, key, ver='v3'):
        self.base = f'http://localhost:{port}'; self.api = f'{self.base}/api/{ver}'; self.h = {'X-Api-Key': key}
    def ready(self): wait(f'{self.base}/ping')
    def get(self, p): return self.call('GET', p)
    def post(self, p, b): return self.call('POST', p, b)
    def put(self, p, b): return self.call('PUT', p, b)
    def call(self, m, p, b=None):
        code, res = req(m, self.api + p, b, self.h)
        if code >= 300: die(f'{m} {p} -> HTTP {code}: {str(res)[:300]}')
        return res
    def set_login(self, user, password):
        hc = self.get('/config/host')
        if hc.get('authenticationMethod') == 'forms' and hc.get('username') == user: return
        hc.update({'authenticationMethod': 'forms', 'authenticationRequired': 'disabledForLocalAddresses',
                   'username': user, 'password': password, 'passwordConfirmation': password})
        self.put(f"/config/host/{hc.get('id', 1)}", hc)
    def from_schema(self, kind, implementation, name, fields, **extra):
        """Create a download client / app / proxy from its schema unless one with this name exists."""
        if any(x.get('name') == name for x in self.get(f'/{kind}')): return False
        s = next(x for x in self.get(f'/{kind}/schema') if x['implementation'] == implementation)
        for f in s['fields']:
            if f['name'] in fields: f['value'] = fields[f['name']]
        s.update({'name': name, **extra}); s.setdefault('enable', True)
        self.post(f'/{kind}', s); return True
