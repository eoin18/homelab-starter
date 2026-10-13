"""RomM: create the first admin user (the API allows this only while no admin exists). Needs RomM's CSRF cookie+header."""
import hsapi
from hsapi import E, req, wait, note
B = 'http://localhost:8090'
wait(B + '/api/heartbeat', timeout=600)
tok = next((c.value for c in hsapi._jar if c.name.endswith('csrftoken')), '')
u = {'username': E['ADMIN_USER'], 'password': E['ADMIN_PASSWORD'], 'email': E.get('ADMIN_EMAIL') or f"{E['ADMIN_USER']}@home.arpa", 'role': 'admin'}
code, r = req('POST', B + '/api/users', u, {'x-csrftoken': tok})
note('admin account created' if code in (200, 201) else f'admin not created (HTTP {code}: {str(r)[:120]}) — probably exists already')
