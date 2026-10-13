"""Navidrome: create the admin account (only possible while no user exists)."""
from hsapi import E, req, wait, note
wait('http://localhost:4533/ping')
code, r = req('POST', 'http://localhost:4533/auth/createAdmin', {'username': E['ADMIN_USER'], 'password': E['ADMIN_PASSWORD']})
note('admin account created' if code == 200 else 'admin already exists')
