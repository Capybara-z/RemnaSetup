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
                    if [ "$NEED_PROTECTION" = "y" ]; then
                        docker rmi remnawave/caddy-with-auth:latest 2>/dev/null || true
                    else
                        docker rmi caddy:2.9 2>/dev/null || true
                    fi
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

install_without_protection() {
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
        if [ -f "docker-compose.yml" ]; then
            sed -i "s|PANEL_DOMAIN=.*|PANEL_DOMAIN=$PANEL_DOMAIN|g" docker-compose.yml
            sed -i "s|SUB_PORT=.*|SUB_PORT=$SUB_PORT|g" docker-compose.yml
        fi

        cd /opt/remnawave && docker compose down && docker compose up -d
        cd /opt/remnawave/subscription && docker compose down && docker compose up -d
        cd /opt/remnawave/caddy && docker compose up -d
    fi
}

install_with_protection() {
    if [ "$REINSTALL_CADDY" = true ]; then
        info "$(get_string "install_caddy_installing")"
        mkdir -p /opt/remnawave/caddy
        cd /opt/remnawave/caddy

        cp "/opt/remnasetup/data/caddy/caddyfile-protection" Caddyfile
        cp "/opt/remnasetup/data/docker/caddy-protection-compose.yml" docker-compose.yml

        sed -i "s|\$PANEL_DOMAIN|$PANEL_DOMAIN|g" docker-compose.yml
        sed -i "s|\$CUSTOM_LOGIN_ROUTE|$CUSTOM_LOGIN_ROUTE|g" docker-compose.yml
        sed -i "s|\$LOGIN_USERNAME|$LOGIN_USERNAME|g" docker-compose.yml
        sed -i "s|\$LOGIN_EMAIL|$LOGIN_EMAIL|g" docker-compose.yml
        sed -i "s|\$LOGIN_PASSWORD|$LOGIN_PASSWORD|g" docker-compose.yml

        sed -i "s|\$PANEL_PORT|$PANEL_PORT|g" Caddyfile
        sed -i "s|\$SUB_DOMAIN|$SUB_DOMAIN|g" Caddyfile
        sed -i "s|\$SUB_PORT|$SUB_PORT|g" Caddyfile

        cd /opt/remnawave
        if [ -f ".env" ]; then
            sed -i "s|PANEL_DOMAIN=.*|PANEL_DOMAIN=$PANEL_DOMAIN|g" .env
            sed -i "s|SUB_DOMAIN=.*|SUB_DOMAIN=$SUB_DOMAIN|g" .env
            sed -i "s|PANEL_PORT=.*|PANEL_PORT=$PANEL_PORT|g" .env
        fi

        cd /opt/remnawave/subscription
        docker compose down
        rm -f docker-compose.yml
        cp "/opt/remnasetup/data/docker/subscription-protection-compose.yml" docker-compose.yml

        sed -i "s|\$PANEL_PORT|$PANEL_PORT|g" docker-compose.yml
        sed -i "s|\$SUB_PORT|$SUB_PORT|g" docker-compose.yml
        sed -i "s|\$PROJECT_NAME|$PROJECT_NAME|g" docker-compose.yml
        sed -i "s|\$PROJECT_DESCRIPTION|$PROJECT_DESCRIPTION|g" docker-compose.yml

        cd /opt/remnawave && docker compose down && docker compose up -d
        cd /opt/remnawave/subscription && docker compose up -d
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
        question "$(get_string "install_caddy_need_protection")"
        NEED_PROTECTION="$REPLY"
        if [[ "$NEED_PROTECTION" == "y" || "$NEED_PROTECTION" == "Y" || "$NEED_PROTECTION" == "n" || "$NEED_PROTECTION" == "N" ]]; then
            break
        fi
        warn "$(get_string "install_caddy_please_enter_yn")"
    done

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

    if [ "$NEED_PROTECTION" = "y" ]; then
        while true; do
            question "$(get_string "install_caddy_enter_project_name")"
            PROJECT_NAME="$REPLY"
            if [[ -n "$PROJECT_NAME" ]]; then
                break
            fi
            warn "$(get_string "install_caddy_project_name_empty")"
        done

        while true; do
            question "$(get_string "install_caddy_enter_project_description")"
            PROJECT_DESCRIPTION="$REPLY"
            if [[ -n "$PROJECT_DESCRIPTION" ]]; then
                break
            fi
            warn "$(get_string "install_caddy_project_description_empty")"
        done

        while true; do
            question "$(get_string "install_caddy_enter_login_route")"
            CUSTOM_LOGIN_ROUTE="$REPLY"
            if [[ -n "$CUSTOM_LOGIN_ROUTE" ]]; then
                break
            fi
            warn "$(get_string "install_caddy_login_route_empty")"
        done

        while true; do
            question "$(get_string "install_caddy_enter_admin_login")"
            LOGIN_USERNAME="$REPLY"
            if [[ -n "$LOGIN_USERNAME" ]]; then
                break
            fi
            warn "$(get_string "install_caddy_admin_login_empty")"
        done

        while true; do
            question "$(get_string "install_caddy_enter_admin_email")"
            LOGIN_EMAIL="$REPLY"
            if [[ -n "$LOGIN_EMAIL" ]]; then
                break
            fi
            warn "$(get_string "install_caddy_admin_email_empty")"
        done

        while true; do
            question "$(get_string "install_caddy_enter_admin_password")"
            LOGIN_PASSWORD="$REPLY"
            if [[ ${#LOGIN_PASSWORD} -lt 8 ]]; then
                warn "$(get_string "install_caddy_password_short")"
                continue
            fi
            if ! [[ "$LOGIN_PASSWORD" =~ [A-Z] ]]; then
                warn "$(get_string "install_caddy_password_uppercase")"
                continue
            fi
            if ! [[ "$LOGIN_PASSWORD" =~ [a-z] ]]; then
                warn "$(get_string "install_caddy_password_lowercase")"
                continue
            fi
            if ! [[ "$LOGIN_PASSWORD" =~ [0-9] ]]; then
                warn "$(get_string "install_caddy_password_number")"
                continue
            fi
            if ! [[ "$LOGIN_PASSWORD" =~ [^a-zA-Z0-9] ]]; then
                warn "$(get_string "install_caddy_password_special")"
                continue
            fi
            break
        done
    fi

    if ! check_docker; then
        install_docker
    fi
    if [ "$NEED_PROTECTION" = "y" ]; then
        install_with_protection
    else
        install_without_protection
    fi

    success "$(get_string "install_caddy_complete")"
    read -n 1 -s -r -p "$(get_string "install_caddy_press_key")"
    exit 0
}

main
