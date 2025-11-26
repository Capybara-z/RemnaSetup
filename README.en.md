# RemnaSetup 🛠️

<div align="center">

[English](README.en.md) | [Русский](README.md)

![RemnaSetup](https://img.shields.io/badge/RemnaSetup-2.5-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-orange)

**Universal script for automatic installation, configuration, and updating of Remnawave and Remnanode infrastructure**

[![Stars](https://img.shields.io/github/stars/Capybara-z/RemnaSetup?style=social)](https://github.com/Capybara-z/RemnaSetup)
[![Forks](https://img.shields.io/github/forks/Capybara-z/RemnaSetup?style=social)](https://github.com/Capybara-z/RemnaSetup)

</div>

---

## 🚀 Features

<div align="center">

### 🔥 Main Components

</div>

<table>
<tr>
<td width="50%" align="center">

### 🎯 Remnawave
- Installation and configuration of control panel
- Installation of subscription page
- Integration with Caddy for request proxying
- Protection of panel and subscriptions
- Automatic component updates

</td>
<td width="50%" align="center">

### 🌐 Remnanode
- Installation and configuration of node
- Integration with Caddy for self-steal
- Network optimization through BBR
- WARP-NATIVE (by distillium) integration
- Automatic component updates

</td>
</tr>
</table>

<div align="center">

---

### 🗄️ Remnawave Backup/Restore

- 💾 Create Remnawave backup
- ♻️ Restore Remnawave from archive
- 📂 Archives stored in /opt/backups
- 📋 Backup types: manual, automatic, with Telegram sending
- 🕒 Automatic backup with configurable schedule

---

</div>

### ⚡ Additional Features
- **Modular structure** with separate scripts
- **Interactive menu** with component selection
- **Automatic updates** of all components
- **Existing installation checks** before installation
- **Reinstallation capability** with data preservation
- **Enhanced error handling** and logging
- **Remnawave backup and restore** through separate menu

---

## 📋 Menu Options

<div align="center">

### 🎮 Interactive Menu

</div>

<table>
<tr>
<td width="50%" align="center">

### 1️⃣ Remnawave
- 📦 Full installation (Remnawave + Subscription Page + Caddy)
- 🚀 Install Remnawave
- 📄 Install Subscription Page
- ⚙️ Install Caddy
- 🔄 Update (Remnawave + Subscription Page)
- 🔄 Update Remnawave
- 🔄 Update Subscription Page

</td>
<td width="50%" align="center">

### 2️⃣ Remnanode
- 📦 Full installation (Remnanode + Caddy + Tblocker + BBR + WARP)
- 🚀 Install Remnanode
- ⚙️ Install Caddy + self-steal
- ⚡ Install BBR
- 🌐 Install WARP-NATIVE (by distillium)
- 🔄 Update Remnanode

</td>
</tr>
</table>

<div align="center">

---

### 3️⃣ Remnawave Backup/Restore

- 💾 Create Remnawave backup
- ♻️ Restore Remnawave from archive
- 📂 Archives stored in /opt/backups
- 🕒 Automatic backup with configurable schedule
- 📤 Send backups to Telegram bot
- 🗑️ Automatic cleanup of old backups
- 🛡️ All actions through convenient menu

---

</div>

---

## 🖥️ Quick Start

- Option 1
```bash
bash <(curl -fsSL raw.githubusercontent.com/Capybara-z/RemnaSetup/refs/heads/main/install.sh)
```
- Option 2
```bash
curl -fsSL https://raw.githubusercontent.com/Capybara-z/RemnaSetup/refs/heads/main/install.sh -o install.sh && chmod +x install.sh && sudo bash ./install.sh
```

---

## 💡 How It Works

<div align="center">

### 🔄 Installation Process

</div>

1. **🎯 Select option** in main menu
2. **📝 Enter data**:
   - 🌐 Domains for panel and subscriptions
   - 🔌 Ports for services
   - 🔑 Database credentials
   - 📊 Metrics settings
   - 🌐 WARP parameters
3. **🗄️ Backup and restore**
4. **⚡ Automation**:
   - ✅ Check existing installations
   - 📦 Install/update components
   - ⚙️ Configure settings
   - 🚀 Start services
   - 📋 View logs

---

## 🛡️ Security

<div align="center">

### 🔒 Security Measures

</div>

- 🔐 Use of sudo only for installation
- 🔑 Manual entry of sensitive data
- 🗑️ Temporary file cleanup
- 📝 Secure configuration storage
- 🔒 Access rights verification
- 🛡️ Input data validation

---

## ⭐️ Project Support

<div align="center">

If the script was helpful — give it a ⭐️ on [GitHub](https://github.com/Capybara-z/RemnaSetup)!

[![Star](https://img.shields.io/github/stars/Capybara-z/RemnaSetup?style=social)](https://github.com/Capybara-z/RemnaSetup)

### 📱 Contacts
 Telegram: [@KaTTuBaRa](https://t.me/KaTTuBaRa)

</div>

---

## 📄 License

MIT

---

<div align="center">

**RemnaSetup** — your universal assistant for quick start and maintenance of Remnawave and RemnaNode infrastructure! 🚀

</div> 