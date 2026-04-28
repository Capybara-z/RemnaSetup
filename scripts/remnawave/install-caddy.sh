#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

REINSTALL_CADDY=false
NEED_PROTECTION=false

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

validate_password() {
    local password="$1"
    local prefix="$2"

    if [[ ${#password} -lt 8 ]]; then
        warn "$(get_string "${prefix}_password_short")"
        return 1
    fi
    if ! [[ "$password" =~ [A-Z] ]]; then
        warn "$(get_string "${prefix}_password_uppercase")"
        return 1
    fi
    if ! [[ "$password" =~ [a-z] ]]; then
        warn "$(get_string "${prefix}_password_lowercase")"
        return 1
    fi
    if ! [[ "$password" =~ [0-9] ]]; then
        warn "$(get_string "${prefix}_password_number")"
        return 1
    fi
    if ! [[ "$password" =~ [^a-zA-Z0-9] ]]; then
        warn "$(get_string "${prefix}_password_special")"
        return 1
    fi
    return 0
}

request_protection_data() {
    while true; do
        question "$(get_string "install_caddy_need_protection")"
        PROTECTION="$REPLY"
        if [[ "$PROTECTION" == "y" || "$PROTECTION" == "Y" ]]; then
            NEED_PROTECTION=true
            break
        elif [[ "$PROTECTION" == "n" || "$PROTECTION" == "N" ]]; then
            NEED_PROTECTION=false
            break
        else
            warn "$(get_string "install_caddy_please_enter_yn")"
        fi
    done

    if [[ "$NEED_PROTECTION" == true ]]; then
        while true; do
            question "$(get_string "install_caddy_enter_login_route")"
            LOGIN_ROUTE="$REPLY"
            if [[ -n "$LOGIN_ROUTE" ]]; then
                LOGIN_ROUTE="${LOGIN_ROUTE#/}"
                break
            fi
            warn "$(get_string "install_caddy_login_route_empty")"
        done

        while true; do
            question "$(get_string "install_caddy_enter_admin_login")"
            ADMIN_LOGIN="$REPLY"
            if [[ -n "$ADMIN_LOGIN" ]]; then
                break
            fi
            warn "$(get_string "install_caddy_admin_login_empty")"
        done

        while true; do
            question "$(get_string "install_caddy_enter_admin_password")"
            ADMIN_PASSWORD="$REPLY"
            if validate_password "$ADMIN_PASSWORD" "install_caddy"; then
                break
            fi
        done
    fi
}

install_caddy() {
    if [ "$REINSTALL_CADDY" = true ]; then
        info "$(get_string "install_caddy_installing")"
        mkdir -p /opt/remnawave/caddy
        cd /opt/remnawave/caddy

        if [[ "$NEED_PROTECTION" == true ]]; then
            cp "/opt/remnasetup/data/caddy/caddyfile-protected" Caddyfile

            ADMIN_PASSWORD_HASH=$(docker run --rm caddy:2.9 caddy hash-password --plaintext "$ADMIN_PASSWORD" 2>/dev/null)
            if [[ -z "$ADMIN_PASSWORD_HASH" ]]; then
                error "Failed to generate password hash. Falling back to standard config."
                cp "/opt/remnasetup/data/caddy/caddyfile" Caddyfile
                NEED_PROTECTION=false
            else
                sed -i "s|\$LOGIN_ROUTE|$LOGIN_ROUTE|g" Caddyfile
                sed -i "s|\$ADMIN_LOGIN|$ADMIN_LOGIN|g" Caddyfile
                sed -i "s|\$ADMIN_PASSWORD_HASH|$ADMIN_PASSWORD_HASH|g" Caddyfile
            fi
        else
            cp "/opt/remnasetup/data/caddy/caddyfile" Caddyfile
        fi

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

    if [[ -n "$PANEL_DOMAIN" ]]; then
        request_protection_data
    fi

    if ! check_docker; then
        install_docker
    fi
    install_caddy

    success "$(get_string "install_caddy_complete")"

    if [[ "$NEED_PROTECTION" == true ]]; then
        echo ""
        echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"
        if [ "$LANGUAGE" = "en" ]; then
            echo -e "${BOLD_CYAN}Panel Protection Info${RESET}"
        else
            echo -e "${BOLD_CYAN}Информация о защите панели${RESET}"
        fi
        echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"
        echo -e "${BOLD_GREEN}URL:${RESET} ${BLUE}https://${PANEL_DOMAIN}/${LOGIN_ROUTE}${RESET}"
        echo -e "${BOLD_GREEN}Login:${RESET} ${BLUE}${ADMIN_LOGIN}${RESET}"
        echo -e "${BOLD_GREEN}Password:${RESET} ${BLUE}${ADMIN_PASSWORD}${RESET}"
        echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"
        echo ""
    fi

    read -n 1 -s -r -p "$(get_string "install_caddy_press_key")"
    exit 0
}

main
