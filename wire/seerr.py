"""Seerr: owner = Jellyfin admin, Jellyfin libraries enabled, Radarr/Sonarr connected, setup completed."""
from hsapi import E, req, wait, die, note, save_secret, installed
B = 'http://localhost:5055/api/v1'
wait(f'{B}/status')
pub = req('GET', f'{B}/settings/public')[1] or {}
c, r = req('POST', f'{B}/auth/jellyfin', {'username': E['ADMIN_USER'], 'password': E['ADMIN_PASSWORD'],
           'hostname': 'host.docker.internal', 'port': 8096, 'useSsl': False, 'urlBase': '',
           'email': f"{E['ADMIN_USER']}@homelab.local", 'serverType': 2})
if c >= 300: die(f'Seerr sign-in via Jellyfin failed: HTTP {c} {r}')
if not pub.get('initialized'):
    libs = req('GET', f'{B}/settings/jellyfin/library?sync=true')[1] or []
    ids = ','.join(l['id'] for l in libs)
    if ids: req('GET', f'{B}/settings/jellyfin/library?enable={ids}'); note(f'Jellyfin libraries: {", ".join(l["name"] for l in libs)}')

def add_arr(kind, port, key_env, folder, extra):
    existing = req('GET', f'{B}/settings/{kind}')[1] or []
    if existing: return
    test = {'hostname': 'host.docker.internal', 'port': port, 'apiKey': E[key_env], 'useSsl': False, 'baseUrl': ''}
    c, t = req('POST', f'{B}/settings/{kind}/test', test)
    if c >= 300: die(f'Seerr could not reach {kind}: HTTP {c} {t}')
    prof = next((p for p in t['profiles'] if p['name'] in ('HD-1080p', 'HD - 720p/1080p')), t['profiles'][0])
    body = {**test, 'name': kind.capitalize(), 'activeProfileId': prof['id'], 'activeProfileName': prof['name'],
            'activeDirectory': folder, 'is4k': False, 'isDefault': True, 'externalUrl': '', 'syncEnabled': True,
            'preventSearch': False, 'tags': [], **extra}
    c, r2 = req('POST', f'{B}/settings/{kind}', body)
    if c >= 300: die(f'adding {kind} to Seerr failed: HTTP {c} {r2}')
    note(f'{kind.capitalize()} connected (profile {prof["name"]})')
if installed('radarr'): add_arr('radarr', 7878, 'RADARR_API_KEY', E['DATA_MOVIES'] + '/library', {'minimumAvailability': 'released'})
if installed('sonarr'): add_arr('sonarr', 8989, 'SONARR_API_KEY', E['DATA_TV'] + '/library',
                                {'seriesType': 'standard', 'animeSeriesType': 'anime', 'enableSeasonFolders': True,
                                 'activeAnimeProfileId': None, 'activeAnimeDirectory': None, 'activeLanguageProfileId': None})
if not pub.get('initialized'):
    req('POST', f'{B}/settings/initialize'); note('setup completed')
if not E.get('SEERR_API_KEY'):
    k = (req('GET', f'{B}/settings/main')[1] or {}).get('apiKey')
    if k: save_secret('SEERR_API_KEY', k)
