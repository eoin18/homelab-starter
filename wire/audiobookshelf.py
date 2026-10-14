"""Audiobookshelf: create the admin (root) account on first start, then an Audiobooks and a Podcasts library."""
from hsapi import E, req, wait, note, die
B = 'http://localhost:13378'
wait(B + '/healthcheck')
code, st = req('GET', B + '/status')
if not (st or {}).get('isInit'):
    code, r = req('POST', B + '/init', {'newRoot': {'username': E['ADMIN_USER'], 'password': E['ADMIN_PASSWORD']}})
    if code != 200: die(f'init -> HTTP {code}: {str(r)[:200]}')
    note('admin account created')
code, r = req('POST', B + '/login', {'username': E['ADMIN_USER'], 'password': E['ADMIN_PASSWORD']})
if code != 200: note('admin password changed in the app: libraries left as they are'); raise SystemExit(0)
u = r['user']; H = {'Authorization': 'Bearer ' + (u.get('accessToken') or u['token'])}
code, libs = req('GET', B + '/api/libraries', headers=H)
have = {l['name'] for l in (libs or {}).get('libraries', [])}
for name, path, kind, icon in (('Audiobooks', E['DATA_AUDIOBOOKS'], 'book', 'audiobookshelf'),
                               ('Podcasts', E['DATA_PODCASTS'], 'podcast', 'podcast')):
    if name in have: continue
    code, r = req('POST', B + '/api/libraries', {'name': name, 'folders': [{'fullPath': path}], 'icon': icon,
                                                 'mediaType': kind, 'provider': 'itunes' if kind == 'podcast' else 'google'}, H)
    note(f'library {name} -> {path}' if code == 200 else f'library {name}: HTTP {code} {str(r)[:150]}')
