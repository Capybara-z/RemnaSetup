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

        if [[ -n "$PANEL_DOMAIN" ]]; then
            sed -i "s|\$PANEL_DOMAIN|$PANEL_DOMAIN|g" Caddyfile
        fi
        if [[ -n "$SUB_DOMAIN" ]]; then
            sed -i "s|\$SUB_DOMAIN|$SUB_DOMAIN|g" Caddyfile
        fi
        if [[ -n "$PANEL_PORT" ]]; then
            sed -i "s|\$PANEL_PORT|$PANEL_PORT|g" Caddyfile
        fi
        if [[ -n "$SUB_PORT" ]]; then
            sed -i "s|\$SUB_PORT|$SUB_PORT|g" Caddyfile
        fi

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

    question "$(get_string "install_caddy_enter_panel_domain")"
    PANEL_DOMAIN="$REPLY"
    if [[ "$PANEL_DOMAIN" != "n" && "$PANEL_DOMAIN" != "N" && -n "$PANEL_DOMAIN" ]]; then
        question "$(get_string "install_caddy_enter_panel_port")"
        PANEL_PORT="$REPLY"
        if [[ "$PANEL_PORT" == "n" || "$PANEL_PORT" == "N" ]]; then
            PANEL_PORT=""
        else
            PANEL_PORT=${PANEL_PORT:-3000}
        fi
    else
        PANEL_DOMAIN=""
        PANEL_PORT=""
    fi

    question "$(get_string "install_caddy_enter_sub_domain")"
    SUB_DOMAIN="$REPLY"
    if [[ "$SUB_DOMAIN" != "n" && "$SUB_DOMAIN" != "N" && -n "$SUB_DOMAIN" ]]; then
        question "$(get_string "install_caddy_enter_sub_port")"
        SUB_PORT="$REPLY"
        if [[ "$SUB_PORT" == "n" || "$SUB_PORT" == "N" ]]; then
            SUB_PORT=""
        else
            SUB_PORT=${SUB_PORT:-3010}
        fi
    else
        SUB_DOMAIN=""
        SUB_PORT=""
    fi

    if ! check_docker; then
        install_docker
    fi
    install_caddy

    success "$(get_string "install_caddy_complete")"
    read -n 1 -s -r -p "$(get_string "install_caddy_press_key")"
    exit 0
}

main
