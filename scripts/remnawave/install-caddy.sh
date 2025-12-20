#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

REINSTALL_CADDY=false

check_component() {
    if [ -f "/opt/remnawave/caddy/docker-compose.yml" ] || [ -f "/opt/remnawave/caddy/Caddyfile" ]; then
        info "$(get_string "install_caddy_detected")"
        while true; do
            question "$(get_string "install_caddy_reinstall")"
            REINSTALL="$REPLY"
            if [[ "$REINSTALL" == "y" || "$REINSTALL" == "Y" ]]; then
                warn "$(get_string "install_caddy_stopping")"
                if [ -f "/opt/remnawave/caddy/docker-compose.yml" ]; then
                    cd /opt/remnawave/caddy && docker compose down
                fi
                if docker ps -a --format '{{.Names}}' | grep -q "remnawave-caddy\|caddy"; then
                    docker rmi caddy:2.9 2>/dev/null || true
                fi
                rm -f /opt/remnawave/caddy/Caddyfile
                rm -f /opt/remnawave/caddy/docker-compose.yml
                REINSTALL_CADDY=true
                break
            elif [[ "$REINSTALL" == "n" || "$REINSTALL" == "N" ]]; then
                info "$(get_string "install_caddy_reinstall_denied")"
                read -n 1 -s -r -p "$(get_string "install_caddy_press_key")"
                exit 0
            else
                warn "$(get_string "install_caddy_please_enter_yn")"
            fi
        done
    else
        REINSTALL_CADDY=true
    fi
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        info "$(get_string "install_caddy_installing")"
        curl -fsSL https://get.docker.com | sh
    fi
}

install_caddy() {
    if [ "$REINSTALL_CADDY" = true ]; then
        info "$(get_string "install_caddy_installing")"
        mkdir -p /opt/remnawave/caddy
        cd /opt/remnawave/caddy

        cp "/opt/remnasetup/data/caddy/caddyfile" Caddyfile
        cp "/opt/remnasetup/data/docker/caddy-compose.yml" docker-compose.yml

        sed -i "s|\$PANEL_DOMAIN|$PANEL_DOMAIN|g" Caddyfile
        sed -i "s|\$SUB_DOMAIN|$SUB_DOMAIN|g" Caddyfile
        sed -i "s|\$PANEL_PORT|$PANEL_PORT|g" Caddyfile
        sed -i "s|\$SUB_PORT|$SUB_PORT|g" Caddyfile

        cd /opt/remnawave
        if [ -f ".env" ]; then
            sed -i "s|PANEL_DOMAIN=.*|PANEL_DOMAIN=$PANEL_DOMAIN|g" .env
            sed -i "s|SUB_DOMAIN=.*|SUB_DOMAIN=$SUB_DOMAIN|g" .env
            sed -i "s|PANEL_PORT=.*|PANEL_PORT=$PANEL_PORT|g" .env
        fi

        cd /opt/remnawave/subscription
        if [ -f ".env" ]; then
            sed -i "s|REMNAWAVE_PANEL_URL=.*|REMNAWAVE_PANEL_URL=https://$PANEL_DOMAIN|g" .env
        fi

        cd /opt/remnawave && docker compose down && docker compose up -d
        cd /opt/remnawave/subscription && docker compose down && docker compose up -d
        cd /opt/remnawave/caddy && docker compose up -d
    fi
}

check_docker() {
    if command -v docker >/dev/null 2>&1; then
        info "$(get_string "install_caddy_detected")"
        return 0
    else
        return 1
    fi
}

main() {
    check_component

    while true; do
        question "$(get_string "install_caddy_enter_panel_domain")"
        PANEL_DOMAIN="$REPLY"
        if [[ -n "$PANEL_DOMAIN" ]]; then
            break
        fi
        warn "$(get_string "install_caddy_domain_empty")"
    done

    while true; do
        question "$(get_string "install_caddy_enter_sub_domain")"
        SUB_DOMAIN="$REPLY"
        if [[ -n "$SUB_DOMAIN" ]]; then
            break
        fi
        warn "$(get_string "install_caddy_domain_empty")"
    done

    question "$(get_string "install_caddy_enter_panel_port")"
    PANEL_PORT="$REPLY"
    PANEL_PORT=${PANEL_PORT:-3000}

    question "$(get_string "install_caddy_enter_sub_port")"
    SUB_PORT="$REPLY"
    SUB_PORT=${SUB_PORT:-3010}

    if ! check_docker; then
        install_docker
    fi
    install_caddy

    success "$(get_string "install_caddy_complete")"
    read -n 1 -s -r -p "$(get_string "install_caddy_press_key")"
    exit 0
}

main
