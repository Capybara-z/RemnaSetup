#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"

check_caddy() {
    if command -v caddy >/dev/null 2>&1; then
        info "Caddy уже установлен"
        question "Хотите скорректировать конфигурацию Caddy? (y/n):"
        UPDATE_CONFIG="$REPLY"
        
        if [[ "$UPDATE_CONFIG" == "y" || "$UPDATE_CONFIG" == "Y" ]]; then
            return 0
        else
            info "Caddy уже установлен"
            read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
            exit 0
            return 1
        fi
    fi
    return 0
}

install_caddy() {
    info "Установка Caddy..."
    sudo apt update -y
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install -y caddy

    success "Caddy успешно установлен!"
}

setup_site() {
    info "Настройка сайта маскировки..."
    sudo chmod -R 777 /var
    sudo mkdir -p /var/www/site
    sudo cp -r "/opt/remnasetup/data/site/"* /var/www/site/
    success "Сайт маскировки настроен!"
}

update_caddy_config() {
    info "Обновление конфигурации Caddy..."
    sudo cp "/opt/remnasetup/data/caddy/caddyfile-node" /etc/caddy/Caddyfile
    sudo sed -i "s/\$DOMAIN/$DOMAIN/g" /etc/caddy/Caddyfile
    sudo sed -i "s/\$MONITOR_PORT/$MONITOR_PORT/g" /etc/caddy/Caddyfile
    sudo systemctl restart caddy
    success "Конфигурация Caddy обновлена!"
}

main() {
    if check_caddy; then
        while true; do
            question "Введите доменное для self-style (например, noda1.domain.com):"
            DOMAIN="$REPLY"
            if [[ -n "$DOMAIN" ]]; then
                break
            fi
            warn "Домен не может быть пустым. Пожалуйста, введите значение."
        done

        while true; do
            question "Введите порт для self-style (по умолчанию 8443):"
            MONITOR_PORT="$REPLY"
            MONITOR_PORT=${MONITOR_PORT:-8443}
            if [[ "$MONITOR_PORT" =~ ^[0-9]+$ ]]; then
                break
            fi
            warn "Порт должен быть числом."
        done

        update_caddy_config
    else
        while true; do
            question "Введите доменное для self-style (например, noda1.domain.com):"
            DOMAIN="$REPLY"
            if [[ -n "$DOMAIN" ]]; then
                break
            fi
            warn "Домен не может быть пустым. Пожалуйста, введите значение."
        done

        while true; do
            question "Введите порт для self-style (по умолчанию 8443):"
            MONITOR_PORT="$REPLY"
            MONITOR_PORT=${MONITOR_PORT:-8443}
            if [[ "$MONITOR_PORT" =~ ^[0-9]+$ ]]; then
                break
            fi
            warn "Порт должен быть числом."
        done

        install_caddy
        setup_site
        update_caddy_config
    fi

    success "Установка завершена!"
    read -n 1 -s -r -p "Нажмите любую клавишу для возврата в меню..."
    exit 0
}

main
