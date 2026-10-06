"""Jellyfin: finish the startup wizard, add libraries, HW transcoding if a GPU exists, API key for other apps."""
import urllib.parse
from hsapi import E, req, wait, die, note, save_secret
B = 'http://localhost:8096'
AUTH = 'MediaBrowser Client="homelab-starter", Device="installer", DeviceId="homelab-starter-installer", Version="1.0"'
wait(f'{B}/System/Info/Public')
info = req('GET', f'{B}/System/Info/Public')[1]
user, pw = E['ADMIN_USER'], E['ADMIN_PASSWORD']
if not info.get('StartupWizardCompleted'):
    req('POST', f'{B}/Startup/Configuration', {'UICulture': 'en-US', 'MetadataCountryCode': 'US', 'PreferredMetadataLanguage': 'en'})
    req('GET', f'{B}/Startup/User')
    c, r = req('POST', f'{B}/Startup/User', {'Name': user, 'Password': pw})
    if c >= 300: die(f'creating Jellyfin admin failed: HTTP {c} {r}')
    req('POST', f'{B}/Startup/RemoteAccess', {'EnableRemoteAccess': True, 'EnableAutomaticPortMapping': False})
    req('POST', f'{B}/Startup/Complete')
    note('setup wizard completed')
c, r = req('POST', f'{B}/Users/AuthenticateByName', {'Username': user, 'Pw': pw}, {'Authorization': AUTH})
if c != 200: die(f'Jellyfin login failed (HTTP {c}) — was the admin password changed?')
H = {'Authorization': f'{AUTH}, Token="{r["AccessToken"]}"'}
have = {f['Name'] for f in req('GET', f'{B}/Library/VirtualFolders', headers=H)[1] or []}
for name, ctype, path in (('Movies', 'movies', '/media/movies'), ('Shows', 'tvshows', '/media/tv')):
    if name in have: continue
    q = urllib.parse.urlencode({'name': name, 'collectionType': ctype, 'paths': path, 'refreshLibrary': 'true'})
    c, r2 = req('POST', f'{B}/Library/VirtualFolders?{q}', {'LibraryOptions': {'PathInfos': [{'Path': path}]}}, H)
    if c >= 300: die(f'adding library {name} failed: HTTP {c} {r2}')
    note(f'library {name} → {path}')
if E.get('GPU') == 'yes':
    enc = req('GET', f'{B}/System/Configuration/encoding', headers=H)[1]
    if enc.get('HardwareAccelerationType') in (None, '', 'none'):
        enc.update({'HardwareAccelerationType': 'vaapi', 'VaapiDevice': '/dev/dri/renderD128', 'EnableHardwareEncoding': True})
        req('POST', f'{B}/System/Configuration/encoding', enc, H); note('hardware transcoding: VA-API')
if not E.get('JELLYFIN_API_KEY'):
    req('POST', f'{B}/Auth/Keys?app=homelab-starter', headers=H)
    keys = req('GET', f'{B}/Auth/Keys', headers=H)[1].get('Items', [])
    k = next((x['AccessToken'] for x in keys if x.get('AppName') == 'homelab-starter'), None)
    if not k: die('could not create a Jellyfin API key')
    save_secret('JELLYFIN_API_KEY', k); note('API key created for Seerr + dashboard')
