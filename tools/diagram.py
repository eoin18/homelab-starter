#!/usr/bin/env python3
"""Render a layered diagram (layers -> themed groups -> apps with icons) to light and dark PNGs.

  tools/diagram.py SPEC.json OUT_PREFIX       writes OUT_PREFIX-light.png and OUT_PREFIX-dark.png

SPEC: {"title": "...", "subtitle": "...", "layers": [
         {"name": "Apps", "note": "...", "groups": [
            {"name": "Watch & listen", "tag": "optional", "items": [
               {"name": "Jellyfin", "icon": "jellyfin", "note": "movies & TV"}]}]},
         {"link": "text on the arrow to the next layer"}, ...]}
Icons are PNGs in an icons/ folder next to SPEC; a missing one is fetched once from the dashboard-icons /
selfh.st CDNs (commit it), else drawn as a letter badge. Needs Chrome/Chromium (CHROME=..., or the copy
puppeteer/mermaid-cli downloads into ~/.cache/puppeteer) and Pillow.
"""
import base64, glob, html, json, os, shutil, subprocess, sys, tempfile, urllib.request
from PIL import Image, ImageChops

if len(sys.argv) != 3: sys.exit(__doc__)
SPEC, OUT = sys.argv[1], sys.argv[2]
spec = json.load(open(SPEC))
ICONS = os.path.join(os.path.dirname(os.path.abspath(SPEC)), 'icons')
CDNS = ['https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/{}.png',
        'https://cdn.jsdelivr.net/gh/selfhst/icons/png/{}.png']


def icon(name, label):
    p = os.path.join(ICONS, f'{name}.png')
    if name and not os.path.exists(p):
        for u in CDNS:
            try:
                data = urllib.request.urlopen(u.format(name), timeout=20).read()
                os.makedirs(ICONS, exist_ok=True); open(p, 'wb').write(data)
                im = Image.open(p).convert('RGBA'); im.thumbnail((96, 96)); im.save(p, optimize=True); break
            except Exception: pass
    if name and os.path.exists(p):
        im = Image.open(p).convert('RGBA'); im.thumbnail((96, 96))
        tmp = tempfile.NamedTemporaryFile(suffix='.png', delete=False); im.save(tmp.name); tmp.close()
        b = base64.b64encode(open(tmp.name, 'rb').read()).decode(); os.remove(tmp.name)
        return f'<img src="data:image/png;base64,{b}">'
    return f'<span class="badge">{html.escape(label[:1])}</span>'


GLYPHS = {   # simple line icons for things that have no logo: "glyph": "folder"
    'folder': '<path d="M3 7h6l2 2h10v10H3z"/>', 'database': '<ellipse cx="12" cy="6" rx="8" ry="3"/><path d="M4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"/>',
    'check': '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 9l2 2 4-4M8 16h8"/>',
    'disk': '<rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="17" cy="12" r="1.5"/><path d="M6 12h7"/>',
    'chip': '<rect x="6" y="6" width="12" height="12" rx="1"/><path d="M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4"/>',
    'devices': '<rect x="2" y="5" width="14" height="10" rx="1"/><path d="M6 19h6"/><rect x="17" y="8" width="5" height="11" rx="1"/>',
    'router': '<rect x="3" y="13" width="18" height="6" rx="1"/><path d="M7 16h.01M11 16h.01M8 13l-2-6M16 13l2-6"/>',
    'gear': '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M5 19l2-2M17 7l2-2"/>',
}


def glyph(name):
    return (f'<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#3b4652" stroke-width="1.8" '
            f'stroke-linecap="round" stroke-linejoin="round">{GLYPHS[name]}</svg>')


def item(it):
    note = f'<small>{html.escape(it["note"])}</small>' if it.get('note') else ''
    return f'<div class="item"><div class="ic">{glyph(it["glyph"]) if it.get("glyph") else icon(it.get("icon", ""), it["name"])}</div><div><b>{html.escape(it["name"])}</b>{note}</div></div>'


def group(g):
    tag = f'<i>{html.escape(g["tag"])}</i>' if g.get('tag') else ''
    return (f'<section class="group" style="--accent:{g.get("color", "var(--ink)")}"><h3>{html.escape(g["name"])}{tag}</h3>'
            f'<div class="items">{"".join(item(i) for i in g["items"])}</div></section>')


def layer(l):
    if 'link' in l: return f'<div class="link"><span>&darr;</span> {html.escape(l["link"])}</div>'
    note = f'<p>{html.escape(l["note"])}</p>' if l.get('note') else ''
    return (f'<div class="layer"><div class="lname"><h2>{html.escape(l["name"])}</h2>{note}</div>'
            f'<div class="groups">{"".join(group(g) for g in l["groups"])}</div></div>')


CSS = """
:root{--bg:#f6f5f1;--card:#fff;--ink:#1d2228;--mute:#66707a;--line:#d9d6cc;--band:#eceae3;--chip:#fff}
.dark{--bg:#0f1316;--card:#192026;--ink:#e8ecef;--mute:#93a0ab;--line:#2c3740;--band:#141a1f;--chip:#eef1f3}
*{box-sizing:border-box;margin:0}
body{background:var(--bg);color:var(--ink);font:15px/1.3 'IBM Plex Sans',sans-serif;width:1400px;padding:36px}
header{margin-bottom:22px} header h1{font:700 30px 'Archivo',sans-serif;letter-spacing:-.01em}
header p{color:var(--mute);margin-top:4px;font-size:16px}
.layer+.layer{margin-top:14px}
.layer{display:grid;grid-template-columns:170px 1fr;gap:16px;background:var(--band);border:1px solid var(--line);
  border-radius:14px;padding:16px}
.lname h2{font:700 13px 'IBM Plex Mono',monospace;text-transform:uppercase;letter-spacing:.08em}
.lname p{color:var(--mute);font-size:13px;margin-top:6px}
.groups{display:flex;flex-wrap:wrap;gap:12px}
.group{background:var(--card);border:1px solid var(--line);border-top:4px solid var(--accent);border-radius:10px;
  padding:10px 12px 12px;flex:1 1 auto}
.group h3{font:600 13px 'IBM Plex Sans',sans-serif;color:var(--mute);margin-bottom:8px;display:flex;gap:8px;align-items:center}
.group h3 i{font:500 11px 'IBM Plex Mono',monospace;font-style:normal;border:1px solid var(--line);border-radius:99px;padding:0 7px}
.items{display:flex;flex-wrap:wrap;gap:8px 14px}
.item{display:flex;gap:8px;align-items:center;min-width:150px}
.item b{font-weight:600;display:block}.item small{color:var(--mute);font-size:12px;display:block}
.ic{width:36px;height:36px;border-radius:9px;background:var(--chip);display:grid;place-items:center;flex:none;
  box-shadow:0 0 0 1px var(--line)}
.ic img{width:26px;height:26px;object-fit:contain}
.badge{font:700 16px 'Archivo',sans-serif;color:#1d2228}
.link{color:var(--mute);font:500 13px 'IBM Plex Mono',monospace;padding:8px 0 8px 186px}
.link span{color:var(--ink);font-size:18px;margin-right:6px}
"""


def page(theme):
    sub = f'<p>{html.escape(spec["subtitle"])}</p>' if spec.get('subtitle') else ''
    return ('<!doctype html><html><head><meta charset="utf-8">'
            '<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@700&family=IBM+Plex+Mono:wght@500;700'
            '&family=IBM+Plex+Sans:wght@400;600&display=block" rel="stylesheet">'
            f'<style>{CSS}</style></head><body class="{theme}"><header><h1>{html.escape(spec["title"])}</h1>{sub}</header>'
            + ''.join(layer(l) for l in spec['layers']) + '</body></html>')


def chrome():
    c = os.environ.get('CHROME') or next((shutil.which(n) for n in ('chromium', 'chromium-browser', 'google-chrome')
                                          if shutil.which(n)), None)
    c = c or next(iter(sorted(glob.glob(os.path.expanduser(
        '~/.cache/puppeteer/chrome-headless-shell/*/*/chrome-headless-shell')), reverse=True)), None)
    if not c: sys.exit('no Chrome found: set CHROME=/path/to/chrome (or run `npx @puppeteer/browsers install chrome-headless-shell`)')
    return c


for theme in ('light', 'dark'):
    with tempfile.TemporaryDirectory() as d:
        src, png = os.path.join(d, 'p.html'), os.path.join(d, 'p.png')
        open(src, 'w').write(page(theme))
        subprocess.run([chrome(), '--headless', '--no-sandbox', '--hide-scrollbars', '--force-device-scale-factor=2',
                        '--window-size=1400,5000', '--virtual-time-budget=8000', f'--screenshot={png}', 'file://' + src],
                       check=True, capture_output=True)
        im = Image.open(png).convert('RGB')
        bg = Image.new('RGB', im.size, im.getpixel((2, 2)))
        box = ImageChops.difference(im, bg).getbbox()
        im = im.crop((0, 0, im.width, min(im.height, box[3] + 72)))   # keep the bottom padding
        im.save(f'{OUT}-{theme}.png', optimize=True)
        print(f'{OUT}-{theme}.png {im.width}x{im.height}')
