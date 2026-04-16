# RemnaSetup

<div align="center">

[English](README.en.md) | [Русский](README.md)

![RemnaSetup](https://img.shields.io/badge/RemnaSetup-2.5-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-orange)

Скрипт для установки и управления инфраструктурой **Remnawave** и **Remnanode**

[![Stars](https://img.shields.io/github/stars/Capybara-z/RemnaSetup?style=social)](https://github.com/Capybara-z/RemnaSetup)

</div>

---

## Установка

```bash
bash <(curl -fsSL raw.githubusercontent.com/Capybara-z/RemnaSetup/refs/heads/main/install.sh)
```

или

```bash
curl -fsSL https://raw.githubusercontent.com/Capybara-z/RemnaSetup/refs/heads/main/install.sh -o install.sh && chmod +x install.sh && sudo bash ./install.sh
```

---

## Возможности

### Remnawave (панель)
- Полная установка (Remnawave + Caddy)
- Установка панели / страницы подписок / Caddy по отдельности
- Обновление всех компонентов
- Бэкап и восстановление (ручной, автоматический, с отправкой в Telegram)

### Remnanode (нода)
- Полная установка (Remnanode + Caddy/Nginx + BBR + WARP)
- Веб-сервер на выбор: **Caddy** или **Nginx** с self-steal
- Nginx: поддержка proxy protocol, сертификаты через Cloudflare DNS-01 / HTTP-01 / Gcore DNS-01
- Управление IPv6
- WARP-NATIVE (by distillium)
- BBR оптимизация

---

## Non-interactive режим

Можно передать параметры через переменные окружения и команду — скрипт выполнится без вопросов.

### Полная установка ноды с Caddy

```bash
DOMAIN=node.example.com \
MONITOR_PORT=8443 \
NODE_PORT=3001 \
SECRET_KEY='ваш_ключ' \
WEBSERVER=caddy \
INSTALL_WARP=y \
BBR_ANSWER=y \
sudo -E bash /opt/remnasetup/remnasetup.sh install-node
```

### Полная установка ноды с Nginx

```bash
DOMAIN=node.example.com \
MONITOR_PORT=8443 \
NODE_PORT=3001 \
SECRET_KEY='ваш_ключ' \
WEBSERVER=nginx \
USE_PROXY_PROTOCOL=n \
CERT_METHOD=1 \
CF_API_KEY='токен' \
CF_EMAIL='email@example.com' \
INSTALL_WARP=y \
BBR_ANSWER=y \
sudo -E bash /opt/remnasetup/remnasetup.sh install-node
```

### Пропуск компонентов

```bash
DOMAIN=node.example.com \
WEBSERVER=caddy \
MONITOR_PORT=8443 \
SKIP_REMNANODE=true \
SKIP_WARP=true \
SKIP_BBR=true \
sudo -E bash /opt/remnasetup/remnasetup.sh install-node
```

### Доступные команды

| Команда | Описание |
|---|---|
| `install-node` | Полная установка ноды |
| `install-node-only` | Только Remnanode |
| `install-caddy-node` | Только Caddy |
| `install-nginx-node` | Только Nginx |
| `install-bbr` | Только BBR |
| `install-warp` | Только WARP |
| `update-node` | Обновить Remnanode |

### Переменные окружения

| Переменная | Описание | По умолчанию |
|---|---|---|
| `DOMAIN` | Домен ноды | — |
| `MONITOR_PORT` | Порт веб-сервера | `8443` |
| `NODE_PORT` | Порт ноды | `3001` |
| `SECRET_KEY` | Ключ подключения к панели | — |
| `WEBSERVER` | `caddy` или `nginx` | — |
| `USE_PROXY_PROTOCOL` | `y` / `n` (для nginx) | — |
| `CERT_METHOD` | `1` (Cloudflare) / `2` (HTTP-01) / `3` (Gcore) | — |
| `CF_API_KEY` | Cloudflare API токен (cert_method=1) | — |
| `CF_EMAIL` | Cloudflare email (cert_method=1) | — |
| `LE_EMAIL` | Email для сертификата (cert_method=2/3) | — |
| `GCORE_API_KEY` | Gcore API токен (cert_method=3) | — |
| `INSTALL_WARP` | `y` / `n` | — |
| `BBR_ANSWER` | `y` / `n` | — |
| `SKIP_WEBSERVER` | `true` — пропустить веб-сервер | — |
| `SKIP_REMNANODE` | `true` — пропустить ноду | — |
| `SKIP_WARP` | `true` — пропустить WARP | — |
| `SKIP_BBR` | `true` — пропустить BBR | — |
| `UPDATE_REMNANODE` | `true` — переустановить ноду | — |
| `UPDATE_CADDY` | `true` — переустановить Caddy | — |
| `UPDATE_NGINX` | `true` — переустановить Nginx | — |
| `LANGUAGE` | `ru` / `en` | `ru` |

Без аргументов скрипт работает в обычном интерактивном режиме через меню.

---

## Контакты

Telegram: [@KaTTuBaRa](https://t.me/KaTTuBaRa)

## Поддержка проекта

Сделано при поддержке [SoloBot](https://github.com/Vladless/Solo_bot) ([@solonet_sup](https://t.me/solonet_sup))

## Лицензия

MIT
