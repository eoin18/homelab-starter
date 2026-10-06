"""Shared wiring for Radarr and Sonarr."""
from hsapi import E, Arr, note

def wire_arr(kind, port, key_env, library, category_field, category):
    a = Arr(port, E[key_env]); a.ready()
    a.set_login(E['ADMIN_USER'], E['ADMIN_PASSWORD'])
    if not any(r['path'].rstrip('/') == library for r in a.get('/rootfolder')):
        a.post('/rootfolder', {'path': library}); note(f'root folder {library}')
    if a.from_schema('downloadclient', 'QBittorrent', 'qBittorrent',
                     {'host': 'host.docker.internal', 'port': 8085, 'useSsl': False,
                      'username': E['ADMIN_USER'], 'password': E['ADMIN_PASSWORD'], category_field: category},
                     priority=1, removeCompletedDownloads=True, removeFailedDownloads=True):
        note(f'qBittorrent client (category {category})')
    mm = a.get('/config/mediamanagement')
    if not mm.get('copyUsingHardlinks'):
        mm['copyUsingHardlinks'] = True; a.put(f"/config/mediamanagement/{mm.get('id', 1)}", mm)
