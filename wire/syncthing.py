"""Syncthing: web-UI login = shared admin, new folders default to $DATA/sync (mounted at /var/syncthing/data)."""
import os, re, time
from hsapi import E, req, wait, note
cfg = os.path.join(E['APPDATA'], 'syncthing', 'config', 'config.xml')
for _ in range(60):
    if os.path.exists(cfg) and '<apikey>' in open(cfg).read(): break
    time.sleep(2)
key = re.search(r'<apikey>([^<]+)</apikey>', open(cfg).read()).group(1)
B = 'http://localhost:8384/rest'; H = {'X-API-Key': key}
wait(B + '/noauth/health')
def call(*a):   # the GUI server restarts after a config change: retry through the reset
    for _ in range(10):
        try: return req(*a)
        except OSError: time.sleep(3)
    raise SystemExit(f'no answer from Syncthing for {a[1]}')
call('PATCH', B + '/config/defaults/folder', {'path': '/var/syncthing/data/'}, H)
code, gui = call('GET', B + '/config/gui', None, H)
if gui.get('user') != E['ADMIN_USER']:
    call('PATCH', B + '/config/gui', {'user': E['ADMIN_USER'], 'password': E['ADMIN_PASSWORD']}, H)
note('login on; new folders go to the sync data folder')
