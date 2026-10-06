# homelab-starter

Build a home server from bundles of self-hosted apps — media, books, ROMs, smart home and more —
installed with Docker and **wired together for you**.

```bash
curl -fsSL https://raw.githubusercontent.com/eoin18/homelab-starter/main/get.sh | sudo bash
```
Prefer to read it first? `git clone https://github.com/eoin18/homelab-starter && sudo ./homelab-starter/install.sh`

**Status: work in progress.** The installer core and the Core bundle work; other bundles are being added.

- Runs on Ubuntu, Debian, Raspberry Pi OS and Fedora (x86_64 or arm64); other Linux if Docker is installed.
- A menu asks which bundles you want, where your media lives and how to log in; answers are saved to
  `config.env` so re-runs need no questions. `install.sh --reconfigure | --add <bundle> | --status`.
- Every password and API key is generated on your machine. Nothing is sent anywhere.
- Download sources are not included: you choose and configure your own indexers, and you are responsible
  for using them legally.

See [DESIGN.md](DESIGN.md) for how it works and what each bundle contains.
