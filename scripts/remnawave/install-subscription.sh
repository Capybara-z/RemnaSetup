#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

REINSTALL_SUBSCRIPTION=false
INSTALL_WITH_PANEL=false

check_component() {
    if [ -f "/opt/remnawave/subscription/docker-compose.yml" ] && (cd /opt/remnawave/subscription && docker compose ps -q | grep -q "remnawave-subscription-page") || [ -f "/opt/remnawave/subscription/.env" ]; then
        info "$(get_string install_subscription_detected)"
        while true; do
            question "$(get_string install_subscription_reinstall)"
            REINSTALL="$REPLY"
            if [[ "$REINSTALL" == "y" || "$REINSTALL" == "Y" ]]; then
                warn "$(get_string install_subscription_stopping)"
                cd /opt/remnawave/subscription && docker compose down
                docker rmi remnawave/subscription-page:latest 2>/dev/null || true
                rm -f /opt/remnawave/subscription/.env
                rm -f /opt/remnawave/subscription/docker-compose.yml
                REINSTALL_SUBSCRIPTION=true
                break
            elif [[ "$REINSTALL" == "n" || "$REINSTALL" == "N" ]]; then
                info "$(get_string install_subscription_reinstall_denied)"
                read -n 1 -s -r -p "$(get_string install_subscription_press_key)"
                exit 0
            else
                warn "$(get_string install_subscription_please_enter_yn)"
            fi
        done
    else
        REINSTALL_SUBSCRIPTION=true
    fi
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        info "$(get_string install_subscription_installing_docker)"
        curl -fsSL https://get.docker.com | sh
    fi
}

install_caddy_for_subscription() {
    if [ ! -f "/opt/remnawave/caddy/Caddyfile" ]; then
        if [ "$LANGUAGE" = "en" ]; then
            info "Installing Caddy for subscription..."
        else
            info "Установка Caddy для страницы подписок..."
        fi
        
        mkdir -p /opt/remnawave/caddy
        cd /opt/remnawave/caddy

        cat > Caddyfile << EOF
https://$SUB_DOMAIN {
    reverse_proxy * http://127.0.0.1:$SUB_PORT
}

:443 {
    tls internal
    respond 204
}
EOF

        cp "/opt/remnasetup/data/docker/caddy-compose.yml" docker-compose.yml

        sed -i '/networks:/d' docker-compose.yml
        sed -i '/- remnawave-network/d' docker-compose.yml
        sed -i '/remnawave-network:/,/external: true/d' docker-compose.yml
        
        docker compose up -d
    else
        update_caddyfile_with_subscription
    fi
}

update_caddyfile_with_subscription() {
    local caddyfile_path="/opt/remnawave/caddy/Caddyfile"
    
    if [ ! -f "$caddyfile_path" ]; then
        return 1
    fi

    local proxy_target
    if [ "$INSTALL_WITH_PANEL" = true ]; then
        proxy_target="remnawave-subscription-page"
    else
        proxy_target="127.0.0.1"
    fi

    if grep -q "https://$SUB_DOMAIN" "$caddyfile_path" || grep -q "https://\$SUB_DOMAIN" "$caddyfile_path"; then
        sed -i "s|https://\$SUB_DOMAIN|https://$SUB_DOMAIN|g" "$caddyfile_path"
        sed -i "s|https://$SUB_DOMAIN {|https://$SUB_DOMAIN {|g" "$caddyfile_path"
        sed -i "s|http://remnawave-subscription-page:\$SUB_PORT|http://$proxy_target:$SUB_PORT|g" "$caddyfile_path"
        sed -i "s|http://remnawave-subscription-page:[0-9]*|http://$proxy_target:$SUB_PORT|g" "$caddyfile_path"
        sed -i "s|http://127.0.0.1:[0-9]*|http://$proxy_target:$SUB_PORT|g" "$caddyfile_path"
    else
        local temp_file=$(mktemp)
        awk -v sub_domain="$SUB_DOMAIN" -v sub_port="$SUB_PORT" -v proxy="$proxy_target" '
            /^:443 {/ {
                print "https://" sub_domain " {"
                print "    reverse_proxy * http://" proxy ":" sub_port
                print "}"
                print ""
            }
            { print }
        ' "$caddyfile_path" > "$temp_file"
        mv "$temp_file" "$caddyfile_path"
    fi

    cd /opt/remnawave/caddy
    docker compose restart 2>/dev/null || docker compose up -d
}


install_subscription() {
    if [ "$REINSTALL_SUBSCRIPTION" = true ]; then
        info "$(get_string install_subscription_installing)"
        mkdir -p /opt/remnawave/subscription
        cd /opt/remnawave/subscription

        cp "/opt/remnasetup/data/docker/subscription.env" .env
        cp "/opt/remnasetup/data/docker/subscription-compose.yml" docker-compose.yml

        sed -i "s|\$SUB_PORT|$SUB_PORT|g" .env
        sed -i "s|\$PANEL_DOMAIN|$PANEL_DOMAIN|g" .env
        sed -i "s|\$API_TOKEN|$API_TOKEN|g" .env

        sed -i "s|\$SUB_PORT|$SUB_PORT|g" docker-compose.yml

        if [ "$INSTALL_WITH_PANEL" = true ]; then
            cd /opt/remnawave
            if [ -f ".env" ]; then
                sed -i "s|SUB_DOMAIN=.*|SUB_DOMAIN=$SUB_DOMAIN|g" .env
            fi

            update_caddyfile_with_subscription

            docker compose down && docker compose up -d 2>/dev/null || true
        else
            sed -i '/networks:/d' docker-compose.yml
            sed -i '/- remnawave-network/d' docker-compose.yml
            sed -i '/remnawave-network:/,/external: true/d' docker-compose.yml

            install_caddy_for_subscription
        fi

        cd /opt/remnawave/subscription
        docker compose down && docker compose up -d
    fi
}

check_docker() {
    if command -v docker >/dev/null 2>&1; then
        info "$(get_string install_subscription_docker_installed)"
        return 0
    else
        return 1
    fi
}

check_panel_installed() {
    if [ -f "/opt/remnawave/.env" ] || [ -f "/opt/remnawave/docker-compose.yml" ]; then
        return 0
    else
        return 1
    fi
}

main() {
    check_component

    while true; do
        if [ "$LANGUAGE" = "en" ]; then
            question "Is subscription installed on the same server as the panel? (y/n):"
        else
            question "Страница подписок устанавливается на том же сервере, что и панель? (y/n):"
        fi
        INSTALL_LOCATION="$REPLY"
        if [[ "$INSTALL_LOCATION" == "y" || "$INSTALL_LOCATION" == "Y" ]]; then
            INSTALL_WITH_PANEL=true
            if ! check_panel_installed; then
                if [ "$LANGUAGE" = "en" ]; then
                    warn "Panel not found. Please install panel first or choose 'n' for separate server installation."
                else
                    warn "Панель не найдена. Пожалуйста, сначала установите панель или выберите 'n' для установки на отдельном сервере."
                fi
                continue
            fi
            break
        elif [[ "$INSTALL_LOCATION" == "n" || "$INSTALL_LOCATION" == "N" ]]; then
            INSTALL_WITH_PANEL=false
            break
        else
            if [ "$LANGUAGE" = "en" ]; then
                warn "Please enter only 'y' or 'n'"
            else
                warn "Пожалуйста, введите только 'y' или 'n'"
            fi
        fi
    done

    while true; do
        question "$(get_string install_subscription_enter_panel_domain)"
        PANEL_DOMAIN="$REPLY"
        if [[ -n "$PANEL_DOMAIN" ]]; then
            break
        fi
        warn "$(get_string install_subscription_domain_empty)"
    done

    while true; do
        question "$(get_string install_subscription_enter_sub_domain)"
        SUB_DOMAIN="$REPLY"
        if [[ -n "$SUB_DOMAIN" ]]; then
            break
        fi
        warn "$(get_string install_subscription_domain_empty)"
    done

    question "$(get_string install_subscription_enter_sub_port)"
    SUB_PORT="$REPLY"
    SUB_PORT=${SUB_PORT:-3010}

    while true; do
        if [ "$LANGUAGE" = "en" ]; then
            question "Enter API Token (Create in Remnawave Dashboard → Remnawave Settings → API Tokens section):"
        else
            question "Введите API токен (Создайте в Remnawave панели → Настройки Remnawave → API токены):"
        fi
        API_TOKEN="$REPLY"
        if [[ -n "$API_TOKEN" ]]; then
            break
        fi
        if [ "$LANGUAGE" = "en" ]; then
            warn "API Token cannot be empty. Please enter a value."
        else
            warn "API токен не может быть пустым. Пожалуйста, введите значение."
        fi
    done

    if ! check_docker; then
        install_docker
    fi
    install_subscription

    success "$(get_string install_subscription_complete)"
    read -n 1 -s -r -p "$(get_string install_subscription_press_key)"
    exit 0
}

main
