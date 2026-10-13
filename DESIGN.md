# homelab-starter — design draft (v0, for review)

A public, one-line installer that builds a fresh home server from a menu of service bundles, wired together
out of the box. Derived from the private `homelab` repo (same service-script format), but with **no personal
data, no secrets, nothing restored** — every install starts clean.

```bash
curl -fsSL https://raw.githubusercontent.com/<you>/homelab-starter/main/get.sh | sudo bash
```

## 1. Supported platforms (v1)
- **Fully supported:** Ubuntu 22.04/24.04, Debian 12, Raspberry Pi OS (64-bit), Fedora — x86_64 and arm64
  (all 29 images publish amd64+arm64, checked 2026-10-06).
- **Best effort:** any other Linux with Docker already installed.
- **VMs** (Ubuntu on a Mac/Windows host): supported with a warning + checklist (bridged networking, real
  virtual disk, USB passthrough or network Zigbee coordinator, no GPU transcoding, host must not sleep).
- **Not in v1:** macOS/Windows Docker Desktop, Synology/Unraid/TrueNAS.

## 2. Bundles
| Bundle id | Services | Depends on | Notes |
|---|---|---|---|
| `core` | homepage, portainer, watchtower | — | always installed |
| `downloads` | qbittorrent, prowlarr, flaresolverr | core | never chosen directly; pulled in by consumers |
| `media-server` | jellyfin | core | GPU (`/dev/dri`) used if detected |
| `movies-tv` | radarr, sonarr, seerr | media-server, downloads | |
| `subtitles` | bazarr | movies-tv | add-on |
| `media-cleanup` | maintainerr | movies-tv | add-on |
| `books` | calibre-web-automated, shelfmark | core (+ downloads for torrent sources) | |
| `games` | romm, romm-db | core | library manager only; no ROM downloader in v1 (gamarr/romarr too unreliable) |
| `smart-home` | homeassistant, mosquitto | core | |
| `zigbee` | zigbee2mqtt | smart-home | needs USB dongle or network coordinator |
| `cameras` | scrypted | smart-home | |
| `dns` | pihole | core | needs a router DNS change; warns about port 53 |
| `monitoring` | netdata, speedtest-tracker | core | |
| `backup` | duplicati | core | user supplies target (local path / B2 / …) |
| `sync` | syncthing | core | |
| `remote-tailscale` | tailscale | core | optional; recommended remote option |
| `remote-cloudflare` | cloudflared | core | advanced: own domain + Cloudflare account |

Dependencies are resolved automatically; the menu shows what gets added and a RAM estimate.

## 3. Repo layout
```
get.sh                 one-liner bootstrap: install git → clone → exec install.sh (≈10 lines, readable)
install.sh             entry point: preflight → menus (if no config.env) → plan → apply → wire → summary
config.env.example     every setting, documented; menus write config.env
lib/
  common.sh            logging, retries, wait_for_http, idempotency markers
  detect.sh            distro, arch, RAM, disks + free space, GPU, Zigbee dongles, VM, ports in use, existing Docker
  pkg.sh               apt / dnf / pacman / zypper shim
  docker.sh            install Docker via get.docker.com (skipped if present)
  menu.sh              whiptail screens
  bundles.sh           dependency resolution, RAM estimate
  secrets.sh           generate + persist secrets (never overwrite existing)
  layout.sh            /data + appdata folders, media group, ownership 2775/664
bundles/<id>.conf      name, description, depends, services, ram_mb, questions
services/<name>.sh     docker run per service — same format as homelab (${VARS}, idempotent recreate)
wire/<name>.sh         post-start configuration via each app's API (idempotent, re-runnable)
homepage/<name>.yaml   dashboard tile/widget template per service
docs/                  README per bundle, VM.md, hardware.md, sources & legal note
tests/vm-test.sh       throwaway-VM harness (shared with the homelab restore drill)
```

## 4. Configuration (`config.env`, written by the menus)
```bash
BUNDLES="core downloads media-server movies-tv subtitles"
TZ="Europe/Dublin"              # detected
PUID=1000; PGID=1001            # admin user + 'media' group (created)
APPDATA="/srv/appdata"
DATA="/data"                    # per-type overrides: DATA_MOVIES, DATA_TV, DATA_BOOKS, DATA_ROMS
ADMIN_USER="admin"              # shared admin login used by every app
GPU="auto"                      # auto | none
ZIGBEE_DEVICE="auto"            # auto | none | /dev/serial/by-id/... | tcp://host:port
REMOTE="none"                   # none | tailscale | cloudflare
TS_AUTHKEY=""                   # optional; else a login link is printed
CF_TUNNEL_TOKEN=""; CF_DOMAIN=""; CF_API_TOKEN=""   # cloudflare only
BACKUP_TARGET=""                # backup bundle only
```
Generated secrets go to `$APPDATA/.secrets.env` (600). A human-readable `$APPDATA/CREDENTIALS.txt` (600)
lists every URL + login at the end.

## 5. Menu flow (whiptail)
1. **Welcome** — what was detected (OS, arch, RAM, disks, GPU, Zigbee, VM warning), port conflicts.
2. **Bundles** — checklist; dependencies auto-added and shown; RAM estimate vs available.
3. **Storage** — where media lives (detected mounts with free space, default `/data`), where app data lives.
   No formatting or fstab edits — paths only.
4. **Basics** — timezone (pre-filled), admin username, password (generate or type).
5. **Remote access** — None / Tailscale / Cloudflare (advanced).
6. **Bundle questions** — only for chosen bundles (Zigbee device, backup target, …).
7. **Review** — services, ports, paths → Install.
Re-runs: `install.sh` (non-interactive with existing config), `--reconfigure` (menus pre-filled),
`--add <bundle>`, `--remove <bundle>` (stops containers, keeps data), `--status`.

## 6. Install pipeline
preflight → install packages/Docker → create layout → generate secrets → start services in dependency order
→ wait until healthy → **wire** → write Homepage config → summary (URLs + CREDENTIALS.txt).

### Wiring — the main value-add (all idempotent, API-driven, lessons from `homelab/docs/gotchas.md`)
- *arr API keys pre-seeded (config.xml / `RADARR__AUTH__APIKEY`-style env) so wiring needs no scraping.
- qBittorrent: admin password set, auto-TMM on, categories `movies tv books games` → `/data/<type>/downloads`,
  ratio 1.0 → remove torrent keep files, global stop at ratio (written to categories.json with qB stopped).
- Prowlarr: FlareSolverr proxy; Radarr/Sonarr registered as apps (full sync). **No indexers** — the user adds
  their own (README explains + legal note).
- Radarr/Sonarr: qBittorrent client (host.docker.internal), root folders `/data/movies/library`, `/data/tv/library`,
  hardlinks on, sensible quality profile left at defaults.
- Jellyfin: startup wizard completed via API (admin user, libraries `/media/movies`, `/media/tvshows`, HW accel if GPU),
  KnownProxies set.
- Seerr: initialised against Jellyfin + Radarr/Sonarr. Bazarr: Radarr/Sonarr + same-path mapping. Maintainerr: Jellyfin/Seerr/arrs.
- Books: CWA library + ingest; Shelfmark → CWA ingest, Prowlarr, qBittorrent `books`.
- Games: RomM + MariaDB (generated passwords), library folder, nightly DB dump cron.
- Smart home: Home Assistant onboarding left to the user (needs their location/account), Mosquitto user created,
  Zigbee2MQTT → Mosquitto; HA MQTT integration pre-filled where possible.
- Homepage: tile + widget for every installed service with keys filled in.
- Remote: Tailscale joins tailnet (optionally Serve for HTTPS names); Cloudflare: routes + Access (email OTP,
  app bypass for Jellyfin/HA, geo-fence) using their API token.

## 7. Conventions (inherited from homelab)
- Every container: `--add-host=host.docker.internal:host-gateway`; host-network apps use `localhost`.
- Single `/data` tree, downloads + library per type on one filesystem, containers mount `/data:/data:rslave`.
- Appdata = `$APPDATA/<service>`; no named/anonymous volumes.
- Watchtower on by default (documented; easy to disable).

## 8. Testing
`tests/vm-test.sh` boots a fresh cloud image (qemu), runs `get.sh` non-interactively with a test `config.env`,
asserts every service healthy + wiring checks (e.g. Radarr sees qBittorrent and Prowlarr). Matrix: Ubuntu 24.04,
Debian 12 (x86); Raspberry Pi OS arm64 on real hardware.

## 9. Decisions (2026-10-06)
- Name/licence: `homelab-starter`, MIT.
- Games bundle: RomM only — neither gamarr nor romarr in v1.
- Default paths: `/data` + `/srv/appdata`.
- Remote: default none; Tailscale recommended, Cloudflare advanced.
- Admin logins: one shared admin username + password across all apps (chosen or generated in the menus; in CREDENTIALS.txt).

## Profiles (decided 2026-10-09) — the starter is also the author's own rebuild engine
- **Bundles stay the user-facing themes.** The menus write `config.env`; a **profile** is the same thing saved ahead of
  time and run non-interactively: `install.sh --profile <dir>` reads `<dir>/profile.env` (BUNDLES + values),
  `<dir>/overrides/<service>.args` (set/unset any docker run flag, image, cmd — see docs/profiles.md) and `<dir>/extras/*.sh` (private services
  that are not in the public catalogue). No personal data ever lands in this repo.
- **`install.sh --render --profile <dir>`** prints the exact `docker run` commands without running anything. Acceptance
  test for the author's server: rendered commands == live containers (semantic compare, zero drift).
- **Catalogue refresh:** Portainer/Netdata/Watchtower → Dockhand (+ its auto-update), Beszel(+agent), Dozzle, Uptime Kuma, ntfy;
  new bundles music (Lidarr, Navidrome, MusicGrabber, Aurral), photos (Immich+ML+Postgres+Valkey), documents (Paperless +
  Tika 3.x pinned + Gotenberg), passwords (Vaultwarden), admin (Termix, Dockhand, Dozzle, Uptime Kuma).
- **Private repo integration:** the private homelab repo pins this repo as a git submodule (a rebuild uses the tested
  commit); its up.sh/bootstrap call the starter with its profile; nightly sync **auto-syncs** live → profile: config diffs on catalogue
  services become `overrides/<svc>` (secrets as ${VAR}), unknown containers become `extras/<name>.sh` (marked unreviewed), removed
  ones are disabled, redundant overrides are pruned; leak scan → commit/push → ntfy summary. Alerts only for diffs that can't be
  expressed as an override. Image digests (Dockhand updates) are ignored. Bumping the starter submodule renders + recreates first,
  so the sync never captures stale live config as overrides that undo catalogue improvements. Personal services (gamarr, romarr, ROM pipeline) stay as profile extras.
- **Build order:** catalogue refresh → profile/overrides/extras/render → author profile until zero drift → switch the private
  repo over (retire its services/) → VM restore drill via the new path (also completes the private repo's Phase F) → tag release.
