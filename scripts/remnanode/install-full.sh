#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

check_docker() {
    if command -v docker >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

install_docker() {
    info "$(get_string "install_full_node_installing_docker")"
    curl -fsSL https://get.docker.com | sh || {
        error "$(get_string "install_full_node_docker_error")"
        exit 1
    }
    success "$(get_string "install_full_node_docker_installed_success")"
}

check_components() {
    if command -v docker >/dev/null 2>&1; then
        info "$(get_string "install_full_node_docker_installed")"
    else
        info "$(get_string "install_full_node_docker_not_installed")"
    fi

    if [ -f "/opt/remnanode/docker-compose.yml" ]; then
        info "$(get_string "install_full_node_remnanode_installed")"
        while true; do
            question "$(get_string "install_full_node_update_remnanode")"
            UPDATE_NODE="$REPLY"
            if [[ "$UPDATE_NODE" == "y" || "$UPDATE_NODE" == "Y" ]]; then
                UPDATE_REMNANODE=true
                break
            elif [[ "$UPDATE_NODE" == "n" || "$UPDATE_NODE" == "N" ]]; then
                SKIP_REMNANODE=true
                break
            else
                warn "$(get_string "install_full_node_please_enter_yn")"
            fi
        done
    fi

    if command -v caddy >/dev/null 2>&1; then
        info "$(get_string "install_full_node_caddy_installed")"
        while true; do
            question "$(get_string "install_full_node_update_caddy")"
            UPDATE_CADDY="$REPLY"
            if [[ "$UPDATE_CADDY" == "y" || "$UPDATE_CADDY" == "Y" ]]; then
                UPDATE_CADDY=true
                break
            elif [[ "$UPDATE_CADDY" == "n" || "$UPDATE_CADDY" == "N" ]]; then
                SKIP_CADDY=true
                break
            else
                warn "$(get_string "install_full_node_please_enter_yn")"
            fi
        done
    fi

    if command -v wgcf >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
        info "$(get_string "warp_native_already_installed")"
        while true; do
            question "$(get_string "warp_native_reconfigure")"
            RECONFIGURE="$REPLY"
            if [[ "$RECONFIGURE" == "y" || "$RECONFIGURE" == "Y" ]]; then
                SKIP_WARP=false
                break
            elif [[ "$RECONFIGURE" == "n" || "$RECONFIGURE" == "N" ]]; then
                SKIP_WARP=true
                info "$(get_string "warp_native_skip_installation")"
                break
            else
                warn "$(get_string "warp_native_please_enter_yn")"
            fi
        done
    else
        SKIP_WARP=false
    fi

    if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        info "$(get_string "install_full_node_bbr_configured")"
        SKIP_BBR=true
    fi
}

request_data() {
    if [[ "$SKIP_CADDY" != "true" ]]; then
        while true; do
            question "$(get_string "install_full_node_enter_domain")"
            DOMAIN="$REPLY"
            if [[ "$DOMAIN" == "n" || "$DOMAIN" == "N" ]]; then
                while true; do
                    question "$(get_string "install_full_node_confirm_skip_caddy")"
                    CONFIRM="$REPLY"
                    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
                        SKIP_CADDY=true
                        break
                    elif [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
                        break
                    else
                        warn "$(get_string "install_full_node_please_enter_yn")"
                    fi
                done
                if [[ "$SKIP_CADDY" == "true" ]]; then
                    break
                fi
            elif [[ -n "$DOMAIN" ]]; then
                break
            fi
            warn "$(get_string "install_full_node_domain_empty")"
        done

        if [[ "$SKIP_CADDY" != "true" ]]; then
            while true; do
                question "$(get_string "install_full_node_enter_port")"
                MONITOR_PORT="$REPLY"
                if [[ "$MONITOR_PORT" == "n" || "$MONITOR_PORT" == "N" ]]; then
                    while true; do
                        question "$(get_string "install_full_node_confirm_skip_caddy")"
                        CONFIRM="$REPLY"
                        if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
                            SKIP_CADDY=true
                            break
                        elif [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
                            break
                        else
                            warn "$(get_string "install_full_node_please_enter_yn")"
                        fi
                    done
                    if [[ "$SKIP_CADDY" == "true" ]]; then
                        break
                    fi
                fi
                MONITOR_PORT=${MONITOR_PORT:-8443}
                if [[ "$MONITOR_PORT" =~ ^[0-9]+$ ]]; then
                    break
                fi
                warn "$(get_string "install_full_node_port_must_be_number")"
            done
        fi
    fi

    if [[ "$SKIP_REMNANODE" != "true" ]]; then
        while true; do
            question "$(get_string "install_full_node_enter_app_port")"
            NODE_PORT="$REPLY"
            if [[ "$NODE_PORT" == "n" || "$NODE_PORT" == "N" ]]; then
                while true; do
                    question "$(get_string "install_full_node_confirm_skip_remnanode")"
                    CONFIRM="$REPLY"
                    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
                        SKIP_REMNANODE=true
                        break
                    elif [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
                        break
                    else
                        warn "$(get_string "install_full_node_please_enter_yn")"
                    fi
                done
                if [[ "$SKIP_REMNANODE" == "true" ]]; then
                    break
                fi
            fi
            NODE_PORT=${NODE_PORT:-3001}
            if [[ "$NODE_PORT" =~ ^[0-9]+$ ]]; then
                break
            fi
            warn "$(get_string "install_full_node_port_must_be_number")"
        done

        if [[ "$SKIP_REMNANODE" != "true" ]]; then
            while true; do
                question "$(get_string "install_full_node_enter_ssl_cert")"
                SECRET_KEY="$REPLY"
                if [[ "$SECRET_KEY" == "n" || "$SECRET_KEY" == "N" ]]; then
                    while true; do
                        question "$(get_string "install_full_node_confirm_skip_remnanode")"
                        CONFIRM="$REPLY"
                        if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
                            SKIP_REMNANODE=true
                            break
                        elif [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
                            break
                        else
                            warn "$(get_string "install_full_node_please_enter_yn")"
                        fi
                    done
                    if [[ "$SKIP_REMNANODE" == "true" ]]; then
                        break
                    fi
                elif [[ -n "$SECRET_KEY" ]]; then
                    break
                fi
                warn "$(get_string "install_full_node_ssl_cert_empty")"
            done
        fi
    fi

    if [[ "$SKIP_WARP" != "true" ]]; then
        while true; do
            question "$(get_string "install_full_node_install_warp_native")"
            INSTALL_WARP="$REPLY"
            if [[ "$INSTALL_WARP" == "n" || "$INSTALL_WARP" == "N" ]]; then
                while true; do
                    question "$(get_string "install_full_node_confirm_skip_warp")"
                    CONFIRM="$REPLY"
                    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
                        SKIP_WARP=true
                        break
                    elif [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
                        break
                    else
                        warn "$(get_string "install_full_node_please_enter_yn")"
                    fi
                done
                if [[ "$SKIP_WARP" == "true" ]]; then
                    break
                fi
            elif [[ "$INSTALL_WARP" == "y" || "$INSTALL_WARP" == "Y" ]]; then
                break
            else
                warn "$(get_string "install_full_node_please_enter_yn")"
            fi
        done
    fi

    if [[ "$SKIP_BBR" != "true" ]]; then
        while true; do
            question "$(get_string "install_full_node_need_bbr")"
            BBR_ANSWER="$REPLY"
            if [[ "$BBR_ANSWER" == "n" || "$BBR_ANSWER" == "N" ]]; then
                SKIP_BBR=true
                break
            elif [[ "$BBR_ANSWER" == "y" || "$BBR_ANSWER" == "Y" ]]; then
                SKIP_BBR=false
                break
            else
                warn "$(get_string "install_full_node_please_enter_yn")"
            fi
        done
    fi
}

RESTORE_DNS_REQUIRED=false

restore_dns() {
    if [[ "$RESTORE_DNS_REQUIRED" == true && -f /etc/resolv.conf.backup ]]; then
        cp /etc/resolv.conf.backup /etc/resolv.conf
        success "$(get_string "warp_native_dns_restored")"
        RESTORE_DNS_REQUIRED=false
    fi
}

uninstall_warp_native() {
    info "$(get_string "warp_native_stopping_warp")"
    
    if ip link show warp &>/dev/null; then
        wg-quick down warp &>/dev/null || true
    fi

    systemctl disable wg-quick@warp &>/dev/null || true

    rm -f /etc/wireguard/warp.conf &>/dev/null
    rm -rf /etc/wireguard &>/dev/null
    rm -f /usr/local/bin/wgcf &>/dev/null
    rm -f wgcf-account.toml wgcf-profile.conf &>/dev/null

    info "$(get_string "warp_native_removing_packages")"
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y wireguard &>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y &>/dev/null || true

    success "$(get_string "warp_native_uninstall_complete")"
}

install_warp() {
    info "$(get_string "warp_native_start_install")"
    echo ""

    info "$(get_string "warp_native_install_wireguard")"
    apt-get update -qq &>/dev/null || {
        error "$(get_string "warp_native_update_failed")"
        exit 1
    }
    apt-get install -y wireguard &>/dev/null || {
        error "$(get_string "warp_native_wireguard_failed")"
        exit 1
    }
    success "$(get_string "warp_native_wireguard_ok")"
    echo ""

    info "$(get_string "warp_native_temp_dns")"
    cp /etc/resolv.conf /etc/resolv.conf.backup
    RESTORE_DNS_REQUIRED=true
    echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > /etc/resolv.conf || {
        error "$(get_string "warp_native_dns_failed")"
        exit 1
    }
    success "$(get_string "warp_native_dns_ok")"
    echo ""

    info "$(get_string "warp_native_download_wgcf")"
    WGCF_RELEASE_URL="https://api.github.com/repos/ViRb3/wgcf/releases/latest"
    WGCF_VERSION=$(curl -s "$WGCF_RELEASE_URL" | grep tag_name | cut -d '"' -f 4)

    if [ -z "$WGCF_VERSION" ]; then
        error "$(get_string "warp_native_wgcf_version_failed")"
        exit 1
    fi

    ARCH=$(uname -m)
    case $ARCH in
        x86_64) WGCF_ARCH="amd64" ;;
        aarch64|arm64) WGCF_ARCH="arm64" ;;
        armv7l) WGCF_ARCH="armv7" ;;
        *) WGCF_ARCH="amd64" ;;
    esac

    info "$(get_string "warp_native_arch_detected") $ARCH -> $WGCF_ARCH"

    WGCF_DOWNLOAD_URL="https://github.com/ViRb3/wgcf/releases/download/${WGCF_VERSION}/wgcf_${WGCF_VERSION#v}_linux_${WGCF_ARCH}"
    WGCF_BINARY_NAME="wgcf_${WGCF_VERSION#v}_linux_${WGCF_ARCH}"

    wget -q "$WGCF_DOWNLOAD_URL" -O "$WGCF_BINARY_NAME" || {
        error "$(get_string "warp_native_wgcf_download_failed")"
        exit 1
    }

    chmod +x "$WGCF_BINARY_NAME" || {
        error "$(get_string "warp_native_wgcf_chmod_failed")"
        exit 1
    }
    mv "$WGCF_BINARY_NAME" /usr/local/bin/wgcf || {
        error "$(get_string "warp_native_wgcf_move_failed")"
        exit 1
    }
    success "wgcf $WGCF_VERSION $(get_string "warp_native_wgcf_installed")"
    echo ""

    info "$(get_string "warp_native_register_wgcf")"

    if [[ -f wgcf-account.toml ]]; then
        info "$(get_string "warp_native_account_exists")"
    else
        info "$(get_string "warp_native_registering")"
        
        info "$(get_string "warp_native_wgcf_binary_check")"
        if ! wgcf --help &>/dev/null; then
            warn "$(get_string "warp_native_wgcf_not_executable")"
            chmod +x /usr/local/bin/wgcf
            if ! wgcf --help &>/dev/null; then
                error "$(get_string "warp_native_wgcf_not_executable")"
                exit 1
            fi
        fi
        
        output=$(timeout 60 bash -c 'yes | wgcf register' 2>&1)
        ret=$?

        if [[ $ret -ne 0 ]]; then
            warn "$(get_string "warp_native_register_error") $ret."
            
            if [[ $ret -eq 126 ]]; then
                warn "$(get_string "warp_native_wgcf_not_executable")"
            elif [[ $ret -eq 124 ]]; then
                warn "Registration timed out after 60 seconds."
            elif [[ "$output" == *"500 Internal Server Error"* ]]; then
                warn "$(get_string "warp_native_cf_500_detected")"
                info "$(get_string "warp_native_known_behavior")"
            elif [[ "$output" == *"429"* || "$output" == *"Too Many Requests"* ]]; then
                warn "$(get_string "warp_native_cf_rate_limited")"
            elif [[ "$output" == *"403"* || "$output" == *"Forbidden"* ]]; then
                warn "$(get_string "warp_native_cf_forbidden")"
            elif [[ "$output" == *"network"* || "$output" == *"connection"* ]]; then
                warn "$(get_string "warp_native_network_issue")"
            else
                warn "$(get_string "warp_native_unknown_error")"
                echo "$output"
            fi
            
            info "$(get_string "warp_native_trying_alternative")"
            echo | wgcf register &>/dev/null || true

    sleep 2
        fi

        if [[ ! -f wgcf-account.toml ]]; then
            error "$(get_string "warp_native_registration_failed")"
            exit 1
        fi

        success "$(get_string "warp_native_account_created")"
    fi

    wgcf generate &>/dev/null || {
        error "$(get_string "warp_native_config_gen_failed")"
        exit 1
    }
    success "$(get_string "warp_native_config_generated")"
    echo ""

    info "$(get_string "warp_native_edit_config")"
    WGCF_CONF_FILE="wgcf-profile.conf"

    if [ ! -f "$WGCF_CONF_FILE" ]; then
        error "$(get_string "warp_native_config_not_found" | sed "s/не найден/Файл $WGCF_CONF_FILE не найден/" | sed "s/not found/File $WGCF_CONF_FILE not found/")"
        exit 1
    fi

    sed -i '/^DNS =/d' "$WGCF_CONF_FILE" || {
        error "$(get_string "warp_native_dns_removed")"
        exit 1
    }

    if ! grep -q "Table = off" "$WGCF_CONF_FILE"; then
        sed -i '/^MTU =/aTable = off' "$WGCF_CONF_FILE" || {
            error "$(get_string "warp_native_table_off_failed")"
            exit 1
        }
    fi

    if ! grep -q "PersistentKeepalive = 25" "$WGCF_CONF_FILE"; then
        sed -i '/^Endpoint =/aPersistentKeepalive = 25' "$WGCF_CONF_FILE" || {
            error "$(get_string "warp_native_keepalive_failed")"
            exit 1
        }
    fi

    mkdir -p /etc/wireguard || {
        error "$(get_string "warp_native_wireguard_dir_failed")"
        exit 1
    }
    mv "$WGCF_CONF_FILE" /etc/wireguard/warp.conf || {
        error "$(get_string "warp_native_config_move_failed")"
        exit 1
    }
    success "$(get_string "warp_native_config_saved")"
    echo ""

    info "$(get_string "warp_native_check_ipv6")"

    is_ipv6_enabled() {
        sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q ' = 0' || return 1
        sysctl net.ipv6.conf.default.disable_ipv6 2>/dev/null | grep -q ' = 0' || return 1
        ip -6 addr show scope global | grep -qv 'inet6 .*fe80::' || return 1
        return 0
    }

    if is_ipv6_enabled; then
        success "$(get_string "warp_native_ipv6_enabled")"
    else
        warn "$(get_string "warp_native_ipv6_disabled")"
        sed -i 's/,\s*[0-9a-fA-F:]\+\/128//' /etc/wireguard/warp.conf
        sed -i '/Address = [0-9a-fA-F:]\+\/128/d' /etc/wireguard/warp.conf
        success "$(get_string "warp_native_ipv6_removed")"
    fi
    echo ""

    info "$(get_string "warp_native_connect_warp")"
    systemctl start wg-quick@warp &>/dev/null || {
        error "$(get_string "warp_native_connect_failed")"
        exit 1
    }
    success "$(get_string "warp_native_warp_connected")"
    echo ""

    info "$(get_string "warp_native_check_status")"

    if ! wg show warp &>/dev/null; then
        error "$(get_string "warp_native_warp_not_found")"
        exit 1
    fi

    for i in {1..10}; do
        handshake=$(wg show warp | grep "latest handshake" | awk -F': ' '{print $2}')
        if [[ "$handshake" == *"second"* || "$handshake" == *"minute"* ]]; then
            success "$(get_string "warp_native_handshake_received") $handshake"
            success "$(get_string "warp_native_warp_active")"
            break
        fi
        sleep 1
    done

    if [[ -z "$handshake" || "$handshake" == "0 seconds ago" ]]; then
        warn "$(get_string "warp_native_handshake_failed")"
    fi

    curl_result=$(curl -s --interface warp https://www.cloudflare.com/cdn-cgi/trace | grep "warp=" | cut -d= -f2)

    if [[ "$curl_result" == "on" ]]; then
        success "$(get_string "warp_native_cf_response")"
    else
        warn "$(get_string "warp_native_cf_not_confirmed")"
    fi
    echo ""

    info "$(get_string "warp_native_enable_autostart")"
    systemctl enable wg-quick@warp &>/dev/null || {
        error "$(get_string "warp_native_autostart_failed")"
        exit 1
    }
    success "$(get_string "warp_native_autostart_enabled")"
    echo ""

    restore_dns
    success "$(get_string "warp_native_installation_complete")"
}

install_bbr() {
    info "$(get_string "install_full_node_installing_bbr")"
    modprobe tcp_bbr
    echo "net.core.default_qdisc=fq" | tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" | tee -a /etc/sysctl.conf
    sysctl -p
    success "$(get_string "install_full_node_bbr_installed_success")"
}

setup_logs_and_logrotate() {
    info "$(get_string "install_full_node_setup_logs")"

    if [ ! -d "/var/log/remnanode" ]; then
        mkdir -p /var/log/remnanode
        chmod -R 777 /var/log/remnanode
        info "$(get_string "install_full_node_logs_dir_created")"
    else
        info "$(get_string "install_full_node_logs_dir_exists")"
    fi

    if ! command -v logrotate >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y logrotate
    fi

    if [ ! -f "/etc/logrotate.d/remnanode" ] || ! grep -q "copytruncate" /etc/logrotate.d/remnanode; then
        tee /etc/logrotate.d/remnanode > /dev/null <<EOF
/var/log/remnanode/*.log {
    size 50M
    rotate 5
    compress
    missingok
    notifempty
    copytruncate
}
EOF
        success "$(get_string "install_full_node_logs_configured")"
    else
        info "$(get_string "install_full_node_logs_already_configured")"
    fi
}

install_caddy() {
    info "$(get_string "install_full_node_installing_caddy")"
    apt-get install -y curl debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -y
    apt-get install -y caddy

    info "$(get_string "install_full_node_setup_site")"
    chmod -R 777 /var

    if [ -d "/var/www/site" ]; then
        rm -rf /var/www/site/*
    else
        mkdir -p /var/www/site
    fi

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

    info "$(get_string "install_full_node_updating_caddy_config")"
    cp "/opt/remnasetup/data/caddy/caddyfile-node" /etc/caddy/Caddyfile
    sed -i "s/\$DOMAIN/$DOMAIN/g" /etc/caddy/Caddyfile
    sed -i "s/\$MONITOR_PORT/$MONITOR_PORT/g" /etc/caddy/Caddyfile
    systemctl restart caddy
    success "$(get_string "install_full_node_caddy_installed_success")"
}

install_remnanode() {
    info "$(get_string "install_full_node_installing_remnanode")"
    chmod -R 777 /opt
    mkdir -p /opt/remnanode

    if [ -n "$SUDO_USER" ]; then
        REAL_USER="$SUDO_USER"
    elif [ -n "$USER" ] && [ "$USER" != "root" ]; then
        REAL_USER="$USER"
    else
        REAL_USER=$(getent passwd 2>/dev/null | awk -F: '$3 >= 1000 && $3 < 65534 && $1 != "nobody" {print $1; exit}')
        if [ -z "$REAL_USER" ]; then
            REAL_USER="root"
        fi
    fi
    
    chown "$REAL_USER:$REAL_USER" /opt/remnanode
    cd /opt/remnanode

    info "$(get_string "install_full_node_using_standard_compose")"
    cp "/opt/remnasetup/data/docker/node-compose.yml" docker-compose.yml

    sed -i "s|\$NODE_PORT|$NODE_PORT|g" docker-compose.yml
    sed -i "s|\$SECRET_KEY|$SECRET_KEY|g" docker-compose.yml

    docker compose up -d || {
        error "$(get_string "install_full_node_remnanode_error")"
        exit 1
    }
    success "$(get_string "install_full_node_remnanode_installed_success")"
}

main() {
    trap restore_dns EXIT
    
    info "$(get_string "install_full_node_start")"

    check_components
    request_data

    info "$(get_string "install_full_node_updating_packages")"
    apt-get update -y

    if ! check_docker; then
        install_docker
    fi

    if [[ "$SKIP_WARP" != "true" ]]; then
        if command -v wgcf >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
            uninstall_warp_native
            echo ""
        fi
        install_warp
    fi
    
    if [[ "$SKIP_BBR" != "true" ]]; then
        install_bbr
    fi
    
    if [[ "$SKIP_CADDY" != "true" ]]; then
        if [[ "$UPDATE_CADDY" == "true" ]]; then
            systemctl stop caddy
            rm -f /etc/caddy/Caddyfile
        fi
        install_caddy
    fi

    setup_logs_and_logrotate
    
    if [[ "$SKIP_REMNANODE" != "true" ]]; then
        if [[ "$UPDATE_REMNANODE" == "true" ]]; then
            cd /opt/remnanode
            docker compose down
            rm -f docker-compose.yml
            rm -f .env
        fi
        install_remnanode
    fi
    
    success "$(get_string "install_full_node_complete")"

    if [[ "$SKIP_WARP" != "true" ]]; then
        echo ""
        echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_check_service"):${RESET} systemctl status wg-quick@warp"
        echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_show_info"):${RESET} wg show warp"
        echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_stop_interface"):${RESET} systemctl stop wg-quick@warp"
        echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_start_interface"):${RESET} systemctl start wg-quick@warp"
        echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_restart_interface"):${RESET} systemctl restart wg-quick@warp"
        echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_disable_autostart"):${RESET} systemctl disable wg-quick@warp"
        echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_enable_autostart_cmd"):${RESET} systemctl enable wg-quick@warp"
        echo ""
    fi
    
    read -n 1 -s -r -p "$(get_string "install_full_node_press_key")"
    exit 0
}

main
