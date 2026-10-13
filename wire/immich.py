"""Immich: create the admin account through the first-run API (closes sign-up for everyone else)."""
from hsapi import E, req, wait, note, todo_add, todo_clear
wait('http://localhost:2283/api/server/ping', timeout=600)
email = E.get('ADMIN_EMAIL') or f"{E['ADMIN_USER']}@home.arpa"
code, r = req('POST', 'http://localhost:2283/api/auth/admin-sign-up', {'email': email, 'password': E['ADMIN_PASSWORD'], 'name': E['ADMIN_USER']})
if code in (200, 201): note(f'admin account {email}')
todo_add('immich', 'Back up your phone with Immich',
    f'Install the <b>Immich</b> app, server <code>http://HOST:2283</code>, log in as <code>{email}</code> with the admin password, '
    'then turn on <b>Backup</b>. Keep the app open on Wi-Fi + charger for the first big upload.')
