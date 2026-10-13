"""Home Assistant: do the first-run onboarding (owner account = shared admin), then add the MQTT integration
pointing at Mosquitto so Zigbee2MQTT devices appear automatically. Re-runs log in and only add what is missing."""
from hsapi import E, req, wait, note, todo_add, todo_clear, installed
B = 'http://localhost:8123'; CID = f"http://{E['HOST_IP']}:8123/"
wait(B + '/manifest.json', timeout=600)
code, steps = req('GET', B + '/api/onboarding')   # 404 once onboarding is finished (after a restart)
done = {s['step'] for s in steps if s.get('done')} if isinstance(steps, list) else {'user'}
if 'user' not in done:
    code, r = req('POST', B + '/api/onboarding/users', {'client_id': CID, 'name': E['ADMIN_USER'], 'username': E['ADMIN_USER'],
                                                       'password': E['ADMIN_PASSWORD'], 'language': 'en'})
    if code != 200:
        todo_add('homeassistant', 'Set up Home Assistant', 'Open <a href="http://HOST:8123">Home Assistant</a> and create your account.')
        raise SystemExit(f'onboarding user -> HTTP {code}: {r}')
    auth_code = r['auth_code']
else:   # already onboarded: log in like the web UI does
    code, f = req('POST', B + '/auth/login_flow', {'client_id': CID, 'handler': ['homeassistant', None], 'redirect_uri': CID})
    code, f = req('POST', f"{B}/auth/login_flow/{f['flow_id']}", {'username': E['ADMIN_USER'], 'password': E['ADMIN_PASSWORD'], 'client_id': CID})
    if f.get('type') != 'create_entry': note('owner account is not the shared admin — leaving Home Assistant alone'); raise SystemExit(0)
    auth_code = f['result']
code, t = req('POST', B + '/auth/token', {'grant_type': 'authorization_code', 'code': auth_code, 'client_id': CID}, form=True)
H = {'Authorization': f"Bearer {t['access_token']}"}
if 'user' not in done:
    req('POST', B + '/api/onboarding/core_config', {}, H)
    req('POST', B + '/api/onboarding/analytics', {}, H)
    req('POST', B + '/api/onboarding/integration', {'client_id': CID, 'redirect_uri': CID + '?auth_callback=1'}, H)
    note(f'owner account {E["ADMIN_USER"]}')
    todo_add('homeassistant', "Check Home Assistant's location",
             'Open <a href="http://HOST:8123/config/general">Home Assistant &rarr; Settings &rarr; System &rarr; General</a> and set your home location, '
             'time zone and units (used for sunrise automations and weather). Install the <b>Home Assistant</b> phone app for notifications and presence.')
if installed('mosquitto'):
    code, entries = req('GET', B + '/api/config/config_entries/entry?domain=mqtt', headers=H)
    if isinstance(entries, list) and entries: raise SystemExit(0)
    code, f = req('POST', B + '/api/config/config_entries/flow', {'handler': 'mqtt', 'show_advanced_options': False}, H)
    if isinstance(f, dict) and f.get('type') == 'menu':
        code, f = req('POST', f"{B}/api/config/config_entries/flow/{f['flow_id']}", {'next_step_id': 'broker'}, H)
    if isinstance(f, dict) and f.get('type') == 'form':
        code, f = req('POST', f"{B}/api/config/config_entries/flow/{f['flow_id']}",
                      {'broker': 'localhost', 'port': 1883, 'protocol': '5',
                       'other_settings': {'set_client_cert': False, 'set_ca_cert': 'off', 'transport': 'tcp'}}, H)
    if isinstance(f, dict) and f.get('type') == 'create_entry':
        todo_clear('homeassistant-mqtt'); note('MQTT integration added (Mosquitto)')
    else:
        todo_add('homeassistant-mqtt', 'Connect Home Assistant to MQTT',
                 'Home Assistant &rarr; Settings &rarr; Devices &amp; services &rarr; Add integration &rarr; <b>MQTT</b>, broker <code>localhost</code>, port 1883.')
        raise SystemExit(f'MQTT flow: {str(f)[:200]}')
