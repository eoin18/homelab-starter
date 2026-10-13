"""Lidarr: login, music root folder (Lossless profile), qBittorrent (category lidarr), and the settings that let it
write proper tags: COPY into the library (hardlinks would change the seeding copy), import cover/lyrics/cue files,
rename into Artist/Album folders, write tags + embed cover art."""
from hsapi import E, Arr, note
a = Arr(8686, E['LIDARR_API_KEY'], 'v1'); a.ready()
a.set_login(E['ADMIN_USER'], E['ADMIN_PASSWORD'])
lib = E['DATA_MUSIC'] + '/library'
if not any(r['path'].rstrip('/') == lib for r in a.get('/rootfolder')):
    qp = {q['name']: q['id'] for q in a.get('/qualityprofile')}; mp = {q['name']: q['id'] for q in a.get('/metadataprofile')}
    a.post('/rootfolder', {'name': 'Music', 'path': lib, 'defaultQualityProfileId': qp.get('Lossless', min(qp.values())),
        'defaultMetadataProfileId': mp.get('Standard', min(mp.values())), 'defaultMonitorOption': 'all',
        'defaultNewItemMonitorOption': 'all', 'defaultTags': []}); note(f'root folder {lib} (Lossless)')
if a.from_schema('downloadclient', 'QBittorrent', 'qBittorrent',
                 {'host': 'host.docker.internal', 'port': 8085, 'useSsl': False, 'username': E['ADMIN_USER'],
                  'password': E['ADMIN_PASSWORD'], 'musicCategory': 'lidarr'},
                 priority=1, removeCompletedDownloads=True, removeFailedDownloads=True):
    note('qBittorrent client (category lidarr)')
mm = a.get('/config/mediamanagement')
mm.update(copyUsingHardlinks=False, importExtraFiles=True, extraFileExtensions='jpg,jpeg,png,lrc,cue,log')
a.put(f"/config/mediamanagement/{mm.get('id', 1)}", mm)
nm = a.get('/config/naming'); nm['renameTracks'] = True; a.put(f"/config/naming/{nm.get('id', 1)}", nm)
md = a.get('/config/metadataprovider'); md.update(writeAudioTags='allFiles', scrubAudioTags=False, embedCoverArt=True)
a.put(f"/config/metadataprovider/{md.get('id', 1)}", md)
note('copy + tag + cover art + extra files')
