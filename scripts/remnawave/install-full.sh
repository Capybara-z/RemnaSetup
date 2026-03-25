#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

REINSTALL_PANEL=false
REINSTALL_CADDY=false
NEED_PROTECTION=false

check_component() {
    local component=$1
    local path=$2
    local env_file=$3

    case $component in
        "panel")
            if [ -f "$path/docker-compose.yml" ] && (cd "$path" && docker compose ps -q | grep -q "remnawave") || [ -f "$env_file" ]; then
                info "$(get_string "install_full_detected")"
                while true; do
                    question "$(get_string "install_full_reinstall")"
                    REINSTALL="$REPLY"
                    if [[ "$REINSTALL" == "y" || "$REINSTALL" == "Y" ]]; then
                        warn "$(get_string "install_full_stopping")"
                        cd "$path" && docker compose down
                        docker rmi remnawave/panel:latest 2>/dev/null || true
                        docker rmi remnawave/redis:latest 2>/dev/null || true
                        docker rmi remnawave/postgres:latest 2>/dev/null || true
                        docker volume rm remnawave-db-data remnawave-redis-data 2>/dev/null || true
                        rm -f "$env_file"
                        rm -f "$path/docker-compose.yml"
                        REINSTALL_PANEL=true
                        break
                    elif [[ "$REINSTALL" == "n" || "$REINSTALL" == "N" ]]; then
                        info "$(get_string "install_full_reinstall_denied")"
                        REINSTALL_PANEL=false
                        break
                    else
                        warn "$(get_string "install_full_please_enter_yn")"
                    fi
                done
            else
                REINSTALL_PANEL=true
            fi
            ;;
        "caddy")
            if [ -f "$path/docker-compose.yml" ] || [ -f "$path/Caddyfile" ]; then
                info "$(get_string "install_full_caddy_detected")"
                while true; do
                    question "$(get_string "install_full_caddy_reinstall")"
                    REINSTALL="$REPLY"
                    if [[ "$REINSTALL" == "y" || "$REINSTALL" == "Y" ]]; then
                        warn "$(get_string "install_full_stopping")"
                        if [ -f "$path/docker-compose.yml" ]; then
                            cd "$path" && docker compose down
                        fi
                        if docker ps -a --format '{{.Names}}' | grep -q "remnawave-caddy\|caddy"; then
                            docker rmi caddy:2.9 2>/dev/null || true
                        fi
                        rm -f "$path/Caddyfile"
                        rm -f "$path/docker-compose.yml"
                        REINSTALL_CADDY=true
                        break
                    elif [[ "$REINSTALL" == "n" || "$REINSTALL" == "N" ]]; then
                        info "$(get_string "install_full_caddy_reinstall_denied")"
                        REINSTALL_CADDY=false
                        break
                    else
                        warn "$(get_string "install_full_please_enter_yn")"
                    fi
                done
            else
                REINSTALL_CADDY=true
            fi
            ;;
    esac
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        info "$(get_string "install_full_installing_docker")"
        curl -fsSL https://get.docker.com | sh
    fi
}

generate_64() {
    openssl rand -hex 64
}

generate_24() {
    openssl rand -hex 24
}

generate_login() {
    tr -dc 'a-zA-Z' < /dev/urandom | head -c 15
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
        question "$(get_string "install_full_need_protection")"
        PROTECTION="$REPLY"
        if [[ "$PROTECTION" == "y" || "$PROTECTION" == "Y" ]]; then
            NEED_PROTECTION=true
            break
        elif [[ "$PROTECTION" == "n" || "$PROTECTION" == "N" ]]; then
            NEED_PROTECTION=false
            break
        else
            warn "$(get_string "install_full_please_enter_yn")"
        fi
    done

    if [[ "$NEED_PROTECTION" == true ]]; then
        while true; do
            question "$(get_string "install_full_enter_login_route")"
            LOGIN_ROUTE="$REPLY"
            if [[ -n "$LOGIN_ROUTE" ]]; then
                LOGIN_ROUTE="${LOGIN_ROUTE#/}"
                break
            fi
            warn "$(get_string "install_full_login_route_empty")"
        done

        while true; do
            question "$(get_string "install_full_enter_admin_login")"
            ADMIN_LOGIN="$REPLY"
            if [[ -n "$ADMIN_LOGIN" ]]; then
                break
            fi
            warn "$(get_string "install_full_admin_login_empty")"
        done

        while true; do
            question "$(get_string "install_full_enter_admin_password")"
            ADMIN_PASSWORD="$REPLY"
            if validate_password "$ADMIN_PASSWORD" "install_full"; then
                break
            fi
        done
    fi
}

install_components() {
    if [ "$REINSTALL_PANEL" = true ]; then
        info "$(get_string "install_full_installing")"
        mkdir -p /opt/remnawave
        cd /opt/remnawave

        cp "/opt/remnasetup/data/docker/panel.env" .env
        cp "/opt/remnasetup/data/docker/panel-compose.yml" docker-compose.yml

        JWT_AUTH_SECRET=$(generate_64)
        JWT_API_TOKENS_SECRET=$(generate_64)
        METRICS_USER=$(generate_login)
        METRICS_PASS=$(generate_64)
        WEBHOOK_SECRET_HEADER=$(generate_64)
        DB_USER=$(generate_login)
        DB_PASSWORD=$(generate_24)

        export DB_USER
        export DB_PASSWORD

        sed -i "s|\$PANEL_DOMAIN|$PANEL_DOMAIN|g" .env
        sed -i "s|\$PANEL_PORT|$PANEL_PORT|g" .env
        sed -i "s|\$METRICS_USER|$METRICS_USER|g" .env
        sed -i "s|\$METRICS_PASS|$METRICS_PASS|g" .env
        sed -i "s|\$DB_USER|$DB_USER|g" .env
        sed -i "s|\$DB_PASSWORD|$DB_PASSWORD|g" .env
        sed -i "s|\$JWT_AUTH_SECRET|$JWT_AUTH_SECRET|g" .env
        sed -i "s|\$JWT_API_TOKENS_SECRET|$JWT_API_TOKENS_SECRET|g" .env
        sed -i "s|\$SUB_DOMAIN|$SUB_DOMAIN|g" .env
        sed -i "s|\$WEBHOOK_SECRET_HEADER|$WEBHOOK_SECRET_HEADER|g" .env

        sed -i "s|\$PANEL_PORT|$PANEL_PORT|g" docker-compose.yml

        docker compose up -d
    fi

    if [ "$REINSTALL_CADDY" = true ]; then
        if [[ "$NEED_PROTECTION" == true ]]; then
            info "$(get_string "install_full_installing_caddy_with_protection")"
        else
            info "$(get_string "install_full_installing_caddy")"
        fi
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

        sed -i "s|\$PANEL_DOMAIN|$PANEL_DOMAIN|g" Caddyfile
        sed -i "s|\$PANEL_PORT|$PANEL_PORT|g" Caddyfile

        docker compose up -d
    fi
}


check_docker() {
    if command -v docker >/dev/null 2>&1; then
        info "$(get_string "install_full_docker_already_installed")"
        return 0
    else
        return 1
    fi
}



show_panel_info() {
    echo ""
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"
    echo -e "${BOLD_CYAN}$(get_string "install_full_panel_info_header")${RESET}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"

    if [[ "$NEED_PROTECTION" == true ]]; then
        echo -e "${BOLD_GREEN}$(get_string "install_full_panel_url")${RESET} ${BLUE}https://${PANEL_DOMAIN}/${LOGIN_ROUTE}${RESET}"
        echo -e "${BOLD_GREEN}Login:${RESET} ${BLUE}${ADMIN_LOGIN}${RESET}"
        echo -e "${BOLD_GREEN}Password:${RESET} ${BLUE}${ADMIN_PASSWORD}${RESET}"
    else
        echo -e "${BOLD_GREEN}$(get_string "install_full_panel_url")${RESET} ${BLUE}https://${PANEL_DOMAIN}${RESET}"
    fi

    
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"
    echo ""
}

main() {
    check_component "panel" "/opt/remnawave" "/opt/remnawave/.env"
    check_component "caddy" "/opt/remnawave/caddy" "/opt/remnawave/caddy/.env"

    if [ "$REINSTALL_PANEL" = false ] && [ "$REINSTALL_CADDY" = false ]; then
        info "$(get_string "install_full_no_components")"
        read -n 1 -s -r -p "$(get_string "install_full_press_key")"
        exit 0
    fi

    while true; do
        question "$(get_string "install_full_enter_panel_domain")"
        PANEL_DOMAIN="$REPLY"
        if [[ -n "$PANEL_DOMAIN" ]]; then
            break
        fi
        warn "$(get_string "install_full_domain_empty")"
    done

    while true; do
        question "$(get_string "install_full_enter_sub_domain")"
        SUB_DOMAIN="$REPLY"
        if [[ -n "$SUB_DOMAIN" ]]; then
            break
        fi
        warn "$(get_string "install_full_domain_empty")"
    done

    question "$(get_string "install_full_enter_panel_port")"
    PANEL_PORT="$REPLY"
    PANEL_PORT=${PANEL_PORT:-3000}

    if [ "$REINSTALL_CADDY" = true ]; then
        request_protection_data
    fi

    if ! check_docker; then
        install_docker
    fi
    install_components

    success "$(get_string "install_full_complete")"

    show_panel_info
    
    read -n 1 -s -r -p "$(get_string "install_full_press_key")"
    exit 0
}

main
