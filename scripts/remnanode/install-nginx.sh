#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

check_nginx() {
    if command -v nginx >/dev/null 2>&1; then
        info "$(get_string "install_nginx_node_already_installed")"
        while true; do
            question "$(get_string "install_nginx_node_update_config")"
            UPDATE_CONFIG="$REPLY"
            if [[ "$UPDATE_CONFIG" == "y" || "$UPDATE_CONFIG" == "Y" ]]; then
                return 0
            elif [[ "$UPDATE_CONFIG" == "n" || "$UPDATE_CONFIG" == "N" ]]; then
                info "$(get_string "install_nginx_node_already_installed")"
                read -n 1 -s -r -p "$(get_string "install_nginx_node_press_key")"
                exit 0
                return 1
            else
                warn "$(get_string "install_nginx_node_please_enter_yn")"
            fi
        done
    fi
    return 0
}

stop_caddy_if_running() {
    if command -v caddy >/dev/null 2>&1; then
        warn "$(get_string "install_nginx_node_caddy_detected")"
        systemctl stop caddy 2>/dev/null || true
        systemctl disable caddy 2>/dev/null || true
        success "$(get_string "install_nginx_node_caddy_stopped")"
    fi
}

install_nginx() {
    info "$(get_string "install_nginx_node_installing")"
    apt-get update -y
    apt-get install -y nginx
    success "$(get_string "install_nginx_node_installed")"
}

install_certbot() {
    info "$(get_string "install_nginx_node_installing_certbot")"
    apt-get install -y certbot
    success "$(get_string "install_nginx_node_certbot_installed")"
}

install_certbot_dns_cloudflare() {
    info "$(get_string "install_nginx_node_installing_cf_plugin")"
    apt-get install -y python3-certbot-dns-cloudflare
    success "$(get_string "install_nginx_node_cf_plugin_installed")"
}

install_certbot_dns_gcore() {
    info "$(get_string "install_nginx_node_installing_gcore_plugin")"
    if ! certbot plugins 2>/dev/null | grep -q "dns-gcore"; then
        apt-get install -y python3-pip >/dev/null 2>&1
        if python3 -m pip install --help 2>&1 | grep -q "break-system-packages"; then
            python3 -m pip install --break-system-packages certbot-dns-gcore
        else
            python3 -m pip install certbot-dns-gcore
        fi

        if certbot plugins 2>/dev/null | grep -q "dns-gcore"; then
            success "$(get_string "install_nginx_node_gcore_plugin_installed")"
        else
            error "$(get_string "install_nginx_node_gcore_plugin_failed")"
            exit 1
        fi
    else
        info "$(get_string "install_nginx_node_gcore_plugin_exists")"
    fi
}

get_certificates() {
    local domain="$1"
    local cert_method="$2"
    local email="$3"
    local base_domain
    base_domain=$(echo "$domain" | awk -F. '{print $(NF-1)"."$NF}')
    local wildcard_domain="*.$base_domain"

    info "$(get_string "install_nginx_node_obtaining_certs") $domain"

    case $cert_method in
        1)
            while true; do
                question "$(get_string "install_nginx_node_enter_cf_token")"
                CF_API_KEY="$REPLY"
                if [[ -n "$CF_API_KEY" ]]; then
                    break
                fi
                warn "$(get_string "install_nginx_node_token_empty")"
            done

            while true; do
                question "$(get_string "install_nginx_node_enter_cf_email")"
                CF_EMAIL="$REPLY"
                if [[ -n "$CF_EMAIL" ]]; then
                    break
                fi
                warn "$(get_string "install_nginx_node_email_empty")"
            done

            install_certbot_dns_cloudflare

            mkdir -p ~/.secrets/certbot
            if [[ $CF_API_KEY =~ [A-Z] ]]; then
                cat > ~/.secrets/certbot/cloudflare.ini <<EOL
dns_cloudflare_api_token = $CF_API_KEY
EOL
            else
                cat > ~/.secrets/certbot/cloudflare.ini <<EOL
dns_cloudflare_email = $CF_EMAIL
dns_cloudflare_api_key = $CF_API_KEY
EOL
            fi
            chmod 600 ~/.secrets/certbot/cloudflare.ini

            certbot certonly \
                --dns-cloudflare \
                --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
                --dns-cloudflare-propagation-seconds 60 \
                -d "$base_domain" \
                -d "$wildcard_domain" \
                --email "$CF_EMAIL" \
                --agree-tos \
                --non-interactive \
                --key-type ecdsa \
                --elliptic-curve secp384r1 || {
                error "$(get_string "install_nginx_node_cert_failed")"
                exit 1
            }
            CERT_DOMAIN="$base_domain"
            ;;
        2)
            while true; do
                question "$(get_string "install_nginx_node_enter_email")"
                LE_EMAIL="$REPLY"
                if [[ -n "$LE_EMAIL" ]]; then
                    break
                fi
                warn "$(get_string "install_nginx_node_email_empty")"
            done

            systemctl stop nginx 2>/dev/null || true

            certbot certonly \
                --standalone \
                -d "$domain" \
                --email "$LE_EMAIL" \
                --agree-tos \
                --non-interactive \
                --key-type ecdsa \
                --elliptic-curve secp384r1 || {
                error "$(get_string "install_nginx_node_cert_failed")"
                systemctl start nginx 2>/dev/null || true
                exit 1
            }
            CERT_DOMAIN="$domain"
            ;;
        3)
            while true; do
                question "$(get_string "install_nginx_node_enter_gcore_token")"
                GCORE_API_KEY="$REPLY"
                if [[ -n "$GCORE_API_KEY" ]]; then
                    break
                fi
                warn "$(get_string "install_nginx_node_token_empty")"
            done

            while true; do
                question "$(get_string "install_nginx_node_enter_email")"
                LE_EMAIL="$REPLY"
                if [[ -n "$LE_EMAIL" ]]; then
                    break
                fi
                warn "$(get_string "install_nginx_node_email_empty")"
            done

            install_certbot_dns_gcore

            mkdir -p ~/.secrets/certbot
            cat > ~/.secrets/certbot/gcore.ini <<EOL
dns_gcore_apitoken = $GCORE_API_KEY
EOL
            chmod 600 ~/.secrets/certbot/gcore.ini

            certbot certonly \
                --authenticator dns-gcore \
                --dns-gcore-credentials ~/.secrets/certbot/gcore.ini \
                --dns-gcore-propagation-seconds 80 \
                -d "$base_domain" \
                -d "$wildcard_domain" \
                --email "$LE_EMAIL" \
                --agree-tos \
                --non-interactive \
                --key-type ecdsa \
                --elliptic-curve secp384r1 || {
                error "$(get_string "install_nginx_node_cert_failed")"
                exit 1
            }
            CERT_DOMAIN="$base_domain"
            ;;
    esac

    success "$(get_string "install_nginx_node_cert_obtained")"
}

setup_certbot_renewal() {
    local cert_method="$1"

    if ! crontab -u root -l 2>/dev/null | grep -q "/usr/bin/certbot renew"; then
        info "$(get_string "install_nginx_node_setup_renewal")"
        local cron_command
        if [ "$cert_method" == "2" ]; then
            cron_command="systemctl stop nginx && /usr/bin/certbot renew --quiet && systemctl start nginx"
        else
            cron_command="/usr/bin/certbot renew --quiet && systemctl reload nginx"
        fi
        (crontab -u root -l 2>/dev/null; echo "0 5 * * 0 $cron_command") | crontab -u root -
        success "$(get_string "install_nginx_node_renewal_configured")"
    else
        info "$(get_string "install_nginx_node_renewal_exists")"
    fi
}

setup_site() {
    info "$(get_string "install_nginx_node_setup_site")"
    mkdir -p /var/www/site
    mkdir -p /var/www/html

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

    success "$(get_string "install_nginx_node_site_configured")"
}

update_nginx_config() {
    info "$(get_string "install_nginx_node_updating_config")"

    cp "/opt/remnasetup/data/nginx/nginx-node.conf" /etc/nginx/nginx.conf

    rm -f /etc/nginx/conf.d/default.conf
    rm -f /etc/nginx/sites-enabled/default

    if [[ "$USE_PROXY_PROTOCOL" == "y" || "$USE_PROXY_PROTOCOL" == "Y" ]]; then
        cp "/opt/remnasetup/data/nginx/selfsteal-proxy-protocol.conf" /etc/nginx/conf.d/selfsteal.conf
    else
        cp "/opt/remnasetup/data/nginx/selfsteal.conf" /etc/nginx/conf.d/selfsteal.conf
    fi

    sed -i "s|\$DOMAIN|$DOMAIN|g" /etc/nginx/conf.d/selfsteal.conf
    sed -i "s|\$MONITOR_PORT|$MONITOR_PORT|g" /etc/nginx/conf.d/selfsteal.conf

    if [[ -n "$CERT_DOMAIN" && "$CERT_DOMAIN" != "$DOMAIN" ]]; then
        sed -i "s|/etc/letsencrypt/live/$DOMAIN|/etc/letsencrypt/live/$CERT_DOMAIN|g" /etc/nginx/conf.d/selfsteal.conf
    fi

    nginx -t || {
        error "$(get_string "install_nginx_node_config_test_failed")"
        exit 1
    }

    systemctl restart nginx
    systemctl enable nginx
    success "$(get_string "install_nginx_node_config_updated")"
}

main() {
    if ! check_nginx; then
        return 1
    fi

    while true; do
        question "$(get_string "install_nginx_node_enter_domain")"
        DOMAIN="$REPLY"
        if [[ -n "$DOMAIN" ]]; then
            break
        fi
        warn "$(get_string "install_nginx_node_domain_empty")"
    done

    while true; do
        question "$(get_string "install_nginx_node_enter_port")"
        MONITOR_PORT="$REPLY"
        MONITOR_PORT=${MONITOR_PORT:-8443}
        if [[ "$MONITOR_PORT" =~ ^[0-9]+$ ]]; then
            break
        fi
        warn "$(get_string "install_nginx_node_port_must_be_number")"
    done

    while true; do
        question "$(get_string "install_nginx_node_use_proxy_protocol")"
        USE_PROXY_PROTOCOL="$REPLY"
        if [[ "$USE_PROXY_PROTOCOL" == "y" || "$USE_PROXY_PROTOCOL" == "Y" || "$USE_PROXY_PROTOCOL" == "n" || "$USE_PROXY_PROTOCOL" == "N" ]]; then
            break
        fi
        warn "$(get_string "install_nginx_node_please_enter_yn")"
    done

    echo ""
    info "$(get_string "install_nginx_node_cert_method_prompt")"
    echo -e "${BLUE}1. Cloudflare DNS-01 (wildcard)${RESET}"
    echo -e "${BLUE}2. HTTP-01 / standalone${RESET}"
    echo -e "${BLUE}3. Gcore DNS-01 (wildcard)${RESET}"
    echo ""
    while true; do
        question "$(get_string "install_nginx_node_cert_method_choose")"
        CERT_METHOD="$REPLY"
        if [[ "$CERT_METHOD" =~ ^[1-3]$ ]]; then
            break
        fi
        warn "$(get_string "install_nginx_node_cert_method_invalid")"
    done

    stop_caddy_if_running

    if ! command -v nginx >/dev/null 2>&1; then
        install_nginx
    fi

    install_certbot

    get_certificates "$DOMAIN" "$CERT_METHOD"

    setup_certbot_renewal "$CERT_METHOD"

    setup_site

    update_nginx_config

    echo ""
    success "$(get_string "install_nginx_node_installation_complete")"

    echo ""
    if [[ "$USE_PROXY_PROTOCOL" == "y" || "$USE_PROXY_PROTOCOL" == "Y" ]]; then
        echo -e "${BOLD_CYAN}Xray Reality config:${RESET}"
        echo -e "${BLUE}  \"target\": \"127.0.0.1:$MONITOR_PORT\",${RESET}"
        echo -e "${BLUE}  \"xver\": 1${RESET}"
    else
        echo -e "${BOLD_CYAN}Xray Reality config:${RESET}"
        echo -e "${BLUE}  \"target\": \"127.0.0.1:$MONITOR_PORT\",${RESET}"
        echo -e "${BLUE}  \"xver\": 0${RESET}"
    fi
    echo ""

    read -n 1 -s -r -p "$(get_string "install_nginx_node_press_key")"
    exit 0
}

main
