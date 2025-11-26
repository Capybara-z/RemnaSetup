#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

REINSTALL_SUBSCRIPTION=false

check_component() {
    if [ -f "/opt/remnawave/subscription/docker-compose.yml" ] && (cd /opt/remnawave/subscription && docker compose ps -q | grep -q "remnawave-subscription-page") || [ -f "/opt/remnawave/subscription/app-config.json" ]; then
        info "$(get_string install_subscription_detected)"
        while true; do
            question "$(get_string install_subscription_reinstall)"
            REINSTALL="$REPLY"
            if [[ "$REINSTALL" == "y" || "$REINSTALL" == "Y" ]]; then
                warn "$(get_string install_subscription_stopping)"
                cd /opt/remnawave/subscription && docker compose down
                docker rmi remnawave/subscription-page:latest 2>/dev/null || true
                rm -f /opt/remnawave/subscription/app-config.json
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

install_subscription() {
    if [ "$REINSTALL_SUBSCRIPTION" = true ]; then
        info "$(get_string install_subscription_installing)"
        mkdir -p /opt/remnawave/subscription
        cd /opt/remnawave/subscription

        cp "/opt/remnasetup/data/app-config.json" app-config.json
        cp "/opt/remnasetup/data/docker/subscription-compose.yml" docker-compose.yml

        sed -i "s|\$PANEL_DOMAIN|$PANEL_DOMAIN|g" docker-compose.yml
        sed -i "s|\$SUB_PORT|$SUB_PORT|g" docker-compose.yml
        sed -i "s|\$PROJECT_NAME|$PROJECT_NAME|g" docker-compose.yml
        sed -i "s|\$PROJECT_DESCRIPTION|$PROJECT_DESCRIPTION|g" docker-compose.yml

        cd /opt/remnawave
        if [ -f ".env" ]; then
            sed -i "s|SUB_DOMAIN=.*|SUB_DOMAIN=$SUB_DOMAIN|g" .env
        fi

        docker compose down && docker compose up -d
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

main() {
    check_component

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
        question "$(get_string install_subscription_enter_project_name)"
        PROJECT_NAME="$REPLY"
        if [[ -n "$PROJECT_NAME" ]]; then
            break
        fi
        warn "$(get_string install_subscription_project_name_empty)"
    done

    while true; do
        question "$(get_string install_subscription_enter_project_description)"
        PROJECT_DESCRIPTION="$REPLY"
        if [[ -n "$PROJECT_DESCRIPTION" ]]; then
            break
        fi
        warn "$(get_string install_subscription_project_description_empty)"
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
