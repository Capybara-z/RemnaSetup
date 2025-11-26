#!/bin/bash

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    echo "Этот скрипт должен быть запущен с правами root"
    exit 1
fi

TEMP_DIR=$(mktemp -d)

if [ -d "/opt/remnasetup" ]; then
    echo "Removing existing RemnaSetup installation..."
    echo "Удаление существующей установки RemnaSetup..."
    rm -rf /opt/remnasetup
fi

if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    echo "Установка curl..."
    if command -v apt-get &> /dev/null; then
        apt-get update -y && apt-get install -y curl
    elif command -v yum &> /dev/null; then
        yum install -y curl
    elif command -v dnf &> /dev/null; then
        dnf install -y curl
    else
        echo "Failed to install curl. Please install it manually."
        echo "Не удалось установить curl. Пожалуйста, установите его вручную."
        exit 1
    fi
fi

cd "$TEMP_DIR" || exit 1

echo "Downloading RemnaSetup..."
echo "Загрузка RemnaSetup..."
curl -L https://github.com/Capybara-z/RemnaSetup/archive/refs/heads/main.zip -o remnasetup.zip

if [ ! -f remnasetup.zip ]; then
    echo "Error: Failed to download archive"
    echo "Ошибка: Не удалось загрузить архив"
    rm -rf "$TEMP_DIR"
    exit 1
fi

if ! command -v unzip &> /dev/null; then
    echo "Installing unzip..."
    echo "Установка unzip..."
    if command -v apt-get &> /dev/null; then
        echo "Updating package list..."
        echo "Обновление списка пакетов..."
        apt-get update -y && apt-get install -y unzip
    elif command -v yum &> /dev/null; then
        yum install -y unzip
    elif command -v dnf &> /dev/null; then
        dnf install -y unzip
    else
        echo "Failed to install unzip. Please install it manually."
        echo "Не удалось установить unzip. Пожалуйста, установите его вручную."
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

echo "Extracting files..."
echo "Распаковка файлов..."
unzip -q remnasetup.zip

if [ ! -d "RemnaSetup-main" ]; then
    echo "Error: Failed to extract archive"
    echo "Ошибка: Не удалось распаковать архив"
    rm -rf "$TEMP_DIR"
    exit 1
fi

mkdir -p /opt/remnasetup

echo "Installing RemnaSetup to /opt/remnasetup..."
echo "Установка RemnaSetup в /opt/remnasetup..."
cp -r RemnaSetup-main/* /opt/remnasetup/

if [ ! -f "/opt/remnasetup/remnasetup.sh" ]; then
    echo "Error: Failed to copy files"
    echo "Ошибка: Не удалось скопировать файлы"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Setting permissions..."
echo "Установка прав доступа..."

if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
elif [ -n "$USER" ] && [ "$USER" != "root" ]; then
    REAL_USER="$USER"
else
    REAL_USER=$(getent passwd 2>/dev/null | awk -F: '$3 >= 1000 && $3 < 65534 && $1 != "nobody" {print $1; exit}')
    if [ -z "$REAL_USER" ]; then
        REAL_USER="root"
    fi
fi

chown -R "$REAL_USER:$REAL_USER" /opt/remnasetup
chmod -R 755 /opt/remnasetup
chmod +x /opt/remnasetup/remnasetup.sh
chmod +x /opt/remnasetup/scripts/common/*.sh
chmod +x /opt/remnasetup/scripts/remnawave/*.sh
chmod +x /opt/remnasetup/scripts/remnanode/*.sh
chmod +x /opt/remnasetup/scripts/backups/*.sh

rm -rf "$TEMP_DIR"

cd /opt/remnasetup || exit 1

echo "Starting RemnaSetup..."
echo "Запуск RemnaSetup..."
bash /opt/remnasetup/remnasetup.sh 
