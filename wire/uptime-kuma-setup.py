"""Configure Uptime Kuma 2.x over its socket.io API (idempotent: monitors matched by name)."""
import os, threading, time, socketio
URL = 'http://127.0.0.1:3002'; USER, PW = os.environ['KUMA_USER'], os.environ['KUMA_PASS']
targets = [l.split('\t') for l in os.environ.get('TARGETS', '').splitlines() if l.strip()]
sio = socketio.Client(reconnection=False); lists = {}; ready = threading.Event()
sio.on('monitorList', lambda d: (lists.__setitem__('monitors', d), ready.set()))
sio.on('notificationList', lambda d: lists.__setitem__('notifications', d))
sio.on('dockerHostList', lambda d: lists.__setitem__('docker', d))
for i in range(30):
    try: sio.connect(URL, transports=['websocket']); break
    except Exception: time.sleep(2)
r = {}
for attempt in range(10):   # first run: create the admin (Kuma refuses once one exists), then log in; retry while it settles
    try: sio.call('setup', (USER, PW), timeout=30)
    except socketio.exceptions.TimeoutError: pass
    r = sio.call('login', {'username': USER, 'password': PW, 'token': ''}, timeout=30)
    if r.get('ok'): break
    time.sleep(3)
if not r.get('ok'): raise SystemExit(f'login failed: {r.get("msg")}')
ready.wait(15)
nid = next((n['id'] for n in lists.get('notifications', []) if n['name'] == 'ntfy homelab'), None)
if nid is None:
    nid = sio.call('addNotification', ({'name': 'ntfy homelab', 'type': 'ntfy', 'isDefault': True, 'applyExisting': True,
        'ntfyserverurl': 'http://host.docker.internal:8086', 'ntfytopic': 'homelab', 'ntfyPriority': 4,
        'ntfyAuthenticationMethod': 'none'}, None), timeout=30).get('id')
did = next((d['id'] for d in lists.get('docker', []) if d['name'] == 'local'), None)
if did is None:
    did = sio.call('addDockerHost', ({'name': 'local', 'dockerType': 'socket', 'dockerDaemon': '/var/run/docker.sock'}, None), timeout=30).get('id')
existing = {m['name'] for m in (lists.get('monitors') or {}).values()}
added = 0
for svc, name, url in targets:
    mname = name if url else f'Container · {svc}'
    if mname in existing or svc == 'uptime-kuma': continue
    m = {'name': mname, 'interval': 60, 'retryInterval': 60, 'maxretries': 2, 'resendInterval': 0, 'active': True,
         'accepted_statuscodes': ['200-399'], 'notificationIDList': {str(nid): True} if nid else {}, 'ignoreTls': True,
         'upsideDown': False, 'maxredirects': 10, 'method': 'GET', 'timeout': 48, 'conditions': [], 'kafkaProducerBrokers': [],
         'kafkaProducerSaslOptions': {}, 'rabbitmqNodes': [], 'description': '', 'httpBodyEncoding': 'json'}
    if url: m.update(type='http', url=url)
    else: m.update(type='docker', docker_container=svc, docker_host=did)
    added += bool(sio.call('add', m, timeout=30).get('ok'))
print(f'uptime-kuma: {added} check(s) added, {len(existing)} already present')
sio.disconnect()
