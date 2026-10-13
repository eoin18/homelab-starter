"""Bazarr: login, connect Sonarr/Radarr, English subtitles by default (language profile 1 for new series/movies)."""
import json, os, re, time
from hsapi import E, req, wait, note, installed
cfg = os.path.join(E['APPDATA'], 'bazarr', 'config', 'config.yaml')
for _ in range(90):
    if os.path.exists(cfg) and re.search(r'apikey: \S', open(cfg).read()): break
    time.sleep(2)
key = re.search(r'^auth:\n(?:  .*\n)*?  apikey: (\S+)', open(cfg).read(), re.M).group(1).strip("'\"")
base = 'http://localhost:6767'; wait(base + '/api/system/status', ok=(200, 401))
H = {'X-API-KEY': key}
s = {'settings-auth-type': 'form', 'settings-auth-username': E['ADMIN_USER'], 'settings-auth-password': E['ADMIN_PASSWORD'],
     'languages-enabled': 'en',
     'languages-profiles': json.dumps([{'profileId': 1, 'name': 'English', 'cutoff': None, 'mustContain': [], 'mustNotContain': [],
                                       'originalFormat': False, 'tag': None,
                                       'items': [{'id': 1, 'language': 'en', 'audio_exclude': 'False', 'audio_only_include': 'False',
                                                  'hi': 'False', 'forced': 'False'}]}]),
     'settings-general-serie_default_enabled': 'true', 'settings-general-serie_default_profile': '1',
     'settings-general-movie_default_enabled': 'true', 'settings-general-movie_default_profile': '1'}
if installed('sonarr'):
    s.update({'settings-general-use_sonarr': 'true', 'settings-sonarr-ip': 'host.docker.internal', 'settings-sonarr-port': '8989',
              'settings-sonarr-apikey': E['SONARR_API_KEY']})
if installed('radarr'):
    s.update({'settings-general-use_radarr': 'true', 'settings-radarr-ip': 'host.docker.internal', 'settings-radarr-port': '7878',
              'settings-radarr-apikey': E['RADARR_API_KEY']})
code, r = req('POST', base + '/api/system/settings', s, H, form=True)
if code >= 300: raise SystemExit(f'settings -> HTTP {code}: {str(r)[:200]}')
note('Sonarr/Radarr connected, English subtitles by default, login on')
