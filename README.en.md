# RemnaSetup

<div align="center">

[English](README.en.md) | [Русский](README.md)

![RemnaSetup](https://img.shields.io/badge/RemnaSetup-2.5-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-orange)

Script for installing and managing **Remnawave** and **Remnanode** infrastructure

[![Stars](https://img.shields.io/github/stars/Capybara-z/RemnaSetup?style=social)](https://github.com/Capybara-z/RemnaSetup)

</div>

---

## Installation

```bash
bash <(curl -fsSL raw.githubusercontent.com/Capybara-z/RemnaSetup/refs/heads/main/install.sh)
```

or

```bash
curl -fsSL https://raw.githubusercontent.com/Capybara-z/RemnaSetup/refs/heads/main/install.sh -o install.sh && chmod +x install.sh && sudo bash ./install.sh
```

---

## Features

### Remnawave (panel)
- Full installation (Remnawave + Caddy)
- Install panel / subscription page / Caddy separately
- Update all components
- Backup and restore (manual, automatic, with Telegram notifications)

### Remnanode (node)
- Full installation (Remnanode + Caddy/Nginx + BBR + WARP)
- Web server choice: **Caddy** or **Nginx** with self-steal
- Nginx: proxy protocol support, certificates via Cloudflare DNS-01 / HTTP-01 / Gcore DNS-01
- IPv6 management
- WARP-NATIVE (by distillium)
- BBR optimization

---

## Non-interactive mode

Pass parameters via environment variables and a command — the script will run without prompts.

### Full node installation with Caddy

```bash
DOMAIN=node.example.com \
MONITOR_PORT=8443 \
NODE_PORT=3001 \
SECRET_KEY="your_key" \
WEBSERVER=caddy \
INSTALL_WARP=y \
BBR_ANSWER=y \
sudo -E bash remnasetup.sh install-node
```

### Full node installation with Nginx

```bash
DOMAIN=node.example.com \
MONITOR_PORT=8443 \
NODE_PORT=3001 \
SECRET_KEY="your_key" \
WEBSERVER=nginx \
USE_PROXY_PROTOCOL=n \
CERT_METHOD=1 \
CF_API_KEY="token" \
CF_EMAIL="email@example.com" \
INSTALL_WARP=y \
BBR_ANSWER=y \
sudo -E bash remnasetup.sh install-node
```

### Skip components

```bash
DOMAIN=node.example.com \
WEBSERVER=caddy \
MONITOR_PORT=8443 \
SKIP_REMNANODE=true \
SKIP_WARP=true \
SKIP_BBR=true \
sudo -E bash remnasetup.sh install-node
```

### Available commands

| Command | Description |
|---|---|
| `install-node` | Full node installation |
| `install-node-only` | Remnanode only |
| `install-caddy-node` | Caddy only |
| `install-nginx-node` | Nginx only |
| `install-bbr` | BBR only |
| `install-warp` | WARP only |
| `update-node` | Update Remnanode |

### Environment variables

| Variable | Description | Default |
|---|---|---|
| `DOMAIN` | Node domain | — |
| `MONITOR_PORT` | Web server port | `8443` |
| `NODE_PORT` | Node port | `3001` |
| `SECRET_KEY` | Panel connection key | — |
| `WEBSERVER` | `caddy` or `nginx` | — |
| `USE_PROXY_PROTOCOL` | `y` / `n` (nginx only) | — |
| `CERT_METHOD` | `1` (Cloudflare) / `2` (HTTP-01) / `3` (Gcore) | — |
| `CF_API_KEY` | Cloudflare API token (cert_method=1) | — |
| `CF_EMAIL` | Cloudflare email (cert_method=1) | — |
| `LE_EMAIL` | Email for certificate (cert_method=2/3) | — |
| `GCORE_API_KEY` | Gcore API token (cert_method=3) | — |
| `INSTALL_WARP` | `y` / `n` | — |
| `BBR_ANSWER` | `y` / `n` | — |
| `SKIP_WEBSERVER` | `true` — skip web server | — |
| `SKIP_REMNANODE` | `true` — skip node | — |
| `SKIP_WARP` | `true` — skip WARP | — |
| `SKIP_BBR` | `true` — skip BBR | — |
| `UPDATE_REMNANODE` | `true` — reinstall node | — |
| `UPDATE_CADDY` | `true` — reinstall Caddy | — |
| `UPDATE_NGINX` | `true` — reinstall Nginx | — |

Without arguments the script runs in interactive menu mode.

---

## Contacts

Telegram: [@KaTTuBaRa](https://t.me/KaTTuBaRa)

## Support

Made with support from [SoloBot](https://github.com/Vladless/Solo_bot) ([@solonet_sup](https://t.me/solonet_sup))

## License

MIT
