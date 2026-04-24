#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

check_caddy() {
    if command -v caddy >/dev/null 2>&1; then
        info "$(get_string "install_caddy_node_already_installed")"

        if [[ "$UPDATE_CONFIG" == "y" || "$UPDATE_CONFIG" == "Y" || "$UPDATE_CONFIG" == "true" ]]; then
            info "UPDATE_CONFIG=$UPDATE_CONFIG, will update..."
            return 0
        fi

        if [[ "$UPDATE_CONFIG" == "n" || "$UPDATE_CONFIG" == "N" || "$UPDATE_CONFIG" == "false" ]]; then
            info "UPDATE_CONFIG=$UPDATE_CONFIG, skipping..."
            pause_press_key "$(get_string "install_caddy_node_press_key")"
            exit 0
        fi

        if is_non_interactive; then
            info "Non-interactive mode: UPDATE_CONFIG not set, defaulting to update."
            return 0
        fi

        while true; do
            question "$(get_string "install_caddy_node_update_config")"
            UPDATE_CONFIG="$REPLY"
            if [[ "$UPDATE_CONFIG" == "y" || "$UPDATE_CONFIG" == "Y" ]]; then
                return 0
            elif [[ "$UPDATE_CONFIG" == "n" || "$UPDATE_CONFIG" == "N" ]]; then
                info "$(get_string "install_caddy_node_already_installed")"
                pause_press_key "$(get_string "install_caddy_node_press_key")"
                exit 0
                return 1
            else
                warn "$(get_string "install_caddy_node_please_enter_yn")"
            fi
        done
    fi
    return 0
}

stop_nginx_if_running() {
    if command -v nginx >/dev/null 2>&1; then
        warn "$(get_string "install_full_node_nginx_detected_stopping")"
        systemctl stop nginx 2>/dev/null || true
        systemctl disable nginx 2>/dev/null || true
    fi
}

install_caddy() {
    stop_nginx_if_running
    info "$(get_string "install_caddy_node_installing")"
    apt-get update -y
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -y
    apt-get install -y caddy

    success "$(get_string "install_caddy_node_installed")"
}

setup_site() {
    info "$(get_string "install_caddy_node_setup_site")"
    mkdir -p /var/www/site
    chmod -R 777 /var/www/site

    RANDOM_META_ID=$(openssl rand -hex 16)
    RANDOM_CLASS=$(openssl rand -hex 8)
    RANDOM_COMMENT=$(openssl rand -hex 12)

    META_NAMES=("render-id" "view-id" "page-id" "config-id")
    RANDOM_META_NAME=${META_NAMES[$RANDOM % ${#META_NAMES[@]}]}
    
    cp -r "/opt/remnasetup/data/site/"* /var/www/site/

    sed -i "/<meta name=\"viewport\"/a \    <meta name=\"$RANDOM_META_NAME\" content=\"$RANDOM_META_ID\">\n    <!-- $RANDOM_COMMENT -->" /var/www/site/index.html
    sed -i "s/<body/<body class=\"$RANDOM_CLASS\"/" /var/www/site/index.html

    sed -i "1i /* $RANDOM_COMMENT */" /var/www/site/assets/style.css
    sed -i "1i // $RANDOM_COMMENT" /var/www/site/assets/main.js
    
    success "$(get_string "install_caddy_node_site_configured")"
}

update_caddy_config() {
    info "$(get_string "install_caddy_node_updating_config")"
    cp "/opt/remnasetup/data/caddy/caddyfile-node" /etc/caddy/Caddyfile
    sed -i "s/\$DOMAIN/$DOMAIN/g" /etc/caddy/Caddyfile
    sed -i "s/\$MONITOR_PORT/$MONITOR_PORT/g" /etc/caddy/Caddyfile
    systemctl restart caddy
    success "$(get_string "install_caddy_node_config_updated")"
}

main() {
    if ! check_caddy; then
        return 1
    fi

    if [[ -n "$DOMAIN" ]]; then
        info "DOMAIN=$DOMAIN"
    else
        if is_non_interactive; then
            error "DOMAIN environment variable is required in non-interactive mode."
            exit 1
        fi
        while true; do
            question "$(get_string "install_caddy_node_enter_domain")"
            DOMAIN="$REPLY"
            if [[ -n "$DOMAIN" ]]; then
                break
            fi
            warn "$(get_string "install_caddy_node_domain_empty")"
        done
    fi

    if [[ -n "$MONITOR_PORT" ]]; then
        if [[ "$MONITOR_PORT" =~ ^[0-9]+$ ]]; then
            info "MONITOR_PORT=$MONITOR_PORT"
        else
            error "$(get_string "install_caddy_node_port_must_be_number")"
            exit 1
        fi
    else
        if is_non_interactive; then
            MONITOR_PORT=8443
            info "Non-interactive mode: MONITOR_PORT defaulted to $MONITOR_PORT"
        else
            while true; do
                question "$(get_string "install_caddy_node_enter_port")"
                MONITOR_PORT="$REPLY"
                MONITOR_PORT=${MONITOR_PORT:-8443}
                if [[ "$MONITOR_PORT" =~ ^[0-9]+$ ]]; then
                    break
                fi
                warn "$(get_string "install_caddy_node_port_must_be_number")"
            done
        fi
    fi

    if ! command -v caddy >/dev/null 2>&1; then
        install_caddy
        setup_site
    fi

    update_caddy_config

    success "$(get_string "install_caddy_node_installation_complete")"
    pause_press_key "$(get_string "install_caddy_node_press_key")"
    exit 0
}

main
