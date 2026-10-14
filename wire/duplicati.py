"""Duplicati: one encrypted nightly job "App settings" = $APPDATA (live database folders excluded; their nightly dumps in
$APPDATA/_dumps are included) -> BACKUP_TARGET, kept 7 daily / 4 weekly / 12 monthly. The passphrase goes in CREDENTIALS.txt."""
import datetime, os, secrets
from hsapi import E, req, wait, note, save_secret, todo_add
B = 'http://localhost:8200/api/v1'
wait('http://localhost:8200/', ok=(200, 301, 302))
code, r = req('POST', B + '/auth/login', {'Password': E['ADMIN_PASSWORD'], 'RememberMe': False})
if code != 200: raise SystemExit(f'login -> HTTP {code}: {str(r)[:200]}')
H = {'Authorization': 'Bearer ' + r['AccessToken']}
code, jobs = req('GET', B + '/backups', headers=H)
if any(j['Backup']['Name'] == 'App settings' for j in jobs or []):
    note('backup job already exists'); raise SystemExit(0)
pp = E.get('BACKUP_PASSPHRASE') or secrets.token_urlsafe(24)
save_secret('BACKUP_PASSPHRASE', pp)
src = '/source' + E['APPDATA'].rstrip('/') + '/'
excl = ['paperless-db', 'immich-db', 'romm-db', 'jellyfin/cache', 'immich-ml', 'romm/redis', 'paperless-redis', 'immich-redis',
        'audiobookshelf/metadata/cache', 'audiobookshelf/metadata/streams', 'audiobookshelf/metadata/logs']
start = (datetime.datetime.now() + datetime.timedelta(days=1)).replace(hour=4, minute=15, second=0, microsecond=0)
body = {'Backup': {'Name': 'App settings', 'Description': 'homelab-starter: app settings + database dumps', 'Tags': [],
                   'TargetURL': 'file:///backups/homelab-starter', 'Sources': [src],
                   'Settings': [{'Name': 'encryption-module', 'Value': 'aes'}, {'Name': 'compression-module', 'Value': 'zip'},
                                {'Name': 'dblock-size', 'Value': '50mb'}, {'Name': 'passphrase', 'Value': pp},
                                {'Name': '--retention-policy', 'Value': '1W:1D,4W:1W,12M:1M'}],
                   'Filters': [{'Order': i, 'Include': False, 'Expression': src + d + '/'} for i, d in enumerate(excl)],
                   'Metadata': {}},
        'Schedule': {'Repeat': '1D', 'Time': start.astimezone().isoformat(), 'AllowedDays': []}}
code, r = req('POST', B + '/backups', body, H)
if code >= 300: raise SystemExit(f'create job -> HTTP {code}: {str(r)[:300]}')
note('nightly job "App settings" -> ' + E.get('BACKUP_TARGET', 'backups folder'))
todo_add('duplicati', 'Keep a copy of your backups off this machine',
         'The nightly backup goes to a folder on this server. To survive a dead disk/fire/theft, add an off-site copy: '
         '<a href="http://HOST:8200">Duplicati</a> &rarr; Add backup &rarr; import or copy "App settings" with a cloud destination '
         '(Backblaze B2, Google Drive, OneDrive…). The backup passphrase is in <code>CREDENTIALS.txt</code> — store it in your password manager: '
         'without it the backups cannot be restored.')
