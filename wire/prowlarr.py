"""Prowlarr: login, FlareSolverr proxy, Radarr/Sonarr as sync targets. No indexers are added on purpose."""
from hsapi import E, Arr, note, installed
p = Arr(9696, E['PROWLARR_API_KEY'], 'v1'); p.ready()
p.set_login(E['ADMIN_USER'], E['ADMIN_PASSWORD'])
if installed('flaresolverr'):
    tags = {t['label']: t['id'] for t in p.get('/tag')}
    tid = tags.get('flaresolverr') or p.post('/tag', {'label': 'flaresolverr'})['id']
    if p.from_schema('indexerProxy', 'FlareSolverr', 'FlareSolverr',
                     {'host': 'http://host.docker.internal:8191/', 'requestTimeout': 60}, tags=[tid]):
        note('FlareSolverr proxy (applies to indexers tagged "flaresolverr")')
apps = {'radarr': ('Radarr', 7878, 'RADARR_API_KEY'), 'sonarr': ('Sonarr', 8989, 'SONARR_API_KEY'), 'lidarr': ('Lidarr', 8686, 'LIDARR_API_KEY')}
for svc, (impl, port, key) in apps.items():
    if installed(svc): Arr(port, E[key], 'v1' if svc == 'lidarr' else 'v3').ready()   # the target must answer Prowlarr's connection test
    if installed(svc) and p.from_schema('applications', impl, impl,
            {'prowlarrUrl': 'http://host.docker.internal:9696', 'baseUrl': f'http://host.docker.internal:{port}', 'apiKey': E[key]},
            syncLevel='fullSync'):
        note(f'{impl} registered for indexer sync')
