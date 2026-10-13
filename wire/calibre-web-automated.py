"""Calibre-Web-Automated ships with admin/admin123: rename that account to the shared admin and set its password.
No API for this, so the user row in app.db is edited with the container stopped (werkzeug pbkdf2 hash, as Calibre-Web writes)."""
import hashlib, os, secrets, sqlite3, subprocess, time
from hsapi import E, note, todo_add, todo_clear
db = os.path.join(E['APPDATA'], 'cwa', 'config', 'app.db')
def ready():
    try: return sqlite3.connect(f'file:{db}?mode=ro', uri=True).execute("select count(*) from user where name='admin'").fetchone()
    except sqlite3.Error: return None
for _ in range(150):
    if ready(): break
    time.sleep(2)
row = ready()
con = sqlite3.connect(db) if row else None
if con and con.execute('select count(*) from user where name=?', (E['ADMIN_USER'],)).fetchone()[0]:
    note('admin already set'); raise SystemExit(0)
if not row or not row[0]:
    todo_add('calibre-web-automated-login', 'Change the Calibre-Web password',
             'Log in to <a href="http://HOST:8083">Calibre-Web</a> as <code>admin</code> / <code>admin123</code>, then Admin &rarr; edit the admin user and change the name and password.')
    raise SystemExit('default admin user not found')
salt = secrets.token_urlsafe(12)
h = f"pbkdf2:sha256:600000${salt}${hashlib.pbkdf2_hmac('sha256', E['ADMIN_PASSWORD'].encode(), salt.encode(), 600000).hex()}"
subprocess.run(['docker', 'stop', 'calibre-web-automated'], check=True, capture_output=True)
try:
    with con: con.execute("update user set name=?, password=? where name='admin'", (E['ADMIN_USER'], h))
finally:
    con.close(); subprocess.run(['docker', 'start', 'calibre-web-automated'], check=True, capture_output=True)
todo_clear('calibre-web-automated-login'); note(f'login {E["ADMIN_USER"]} (was admin/admin123)')
