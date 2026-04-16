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
        if [[ "$SKIP_REMNANODE" == "true" ]]; then
            info "SKIP_REMNANODE=true, skipping..."
        elif [[ "$UPDATE_REMNANODE" == "true" ]]; then
            info "UPDATE_REMNANODE=true, will update..."
        else
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
    fi

    if command -v caddy >/dev/null 2>&1; then
        info "$(get_string "install_full_node_caddy_installed")"
        DETECTED_WEBSERVER="caddy"
        if [[ "$SKIP_WEBSERVER" == "true" ]]; then
            info "SKIP_WEBSERVER=true, skipping..."
        elif [[ -n "$WEBSERVER" ]]; then
            if [[ "$WEBSERVER" == "caddy" ]]; then
                UPDATE_CADDY=true
                info "WEBSERVER=caddy, will update..."
            fi
        elif [[ "$UPDATE_CADDY" == "true" ]]; then
            info "UPDATE_CADDY=true, will update..."
        else
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
    fi

    if command -v nginx >/dev/null 2>&1; then
        info "$(get_string "install_full_node_nginx_installed")"
        if [[ -z "$DETECTED_WEBSERVER" ]]; then
            DETECTED_WEBSERVER="nginx"
        fi
        if [[ "$SKIP_WEBSERVER" == "true" ]]; then
            info "SKIP_WEBSERVER=true, skipping..."
        elif [[ -n "$WEBSERVER" ]]; then
            if [[ "$WEBSERVER" == "nginx" ]]; then
                UPDATE_NGINX=true
                info "WEBSERVER=nginx, will update..."
            fi
        elif [[ "$UPDATE_NGINX" == "true" ]]; then
            info "UPDATE_NGINX=true, will update..."
        else
            while true; do
                question "$(get_string "install_full_node_update_nginx")"
                UPDATE_NGINX="$REPLY"
                if [[ "$UPDATE_NGINX" == "y" || "$UPDATE_NGINX" == "Y" ]]; then
                    UPDATE_NGINX=true
                    break
                elif [[ "$UPDATE_NGINX" == "n" || "$UPDATE_NGINX" == "N" ]]; then
                    SKIP_NGINX=true
                    break
                else
                    warn "$(get_string "install_full_node_please_enter_yn")"
                fi
            done
        fi
    fi

    if command -v wgcf >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
        info "$(get_string "warp_native_already_installed")"
        if [[ "$SKIP_WARP" == "true" ]]; then
            info "SKIP_WARP=true, skipping..."
        elif [[ "$INSTALL_WARP" == "n" || "$INSTALL_WARP" == "N" ]]; then
            SKIP_WARP=true
            info "INSTALL_WARP=$INSTALL_WARP, skipping..."
        elif [[ "$INSTALL_WARP" == "y" || "$INSTALL_WARP" == "Y" ]]; then
            SKIP_WARP=true
            info "WARP already installed, skipping..."
        elif [[ "$SKIP_WARP" == "false" ]]; then
            :
        else
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
        fi
    else
        if [[ -z "$SKIP_WARP" ]]; then
            SKIP_WARP=false
        fi
    fi

    if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        info "$(get_string "install_full_node_bbr_configured")"
        SKIP_BBR=true
    fi
}

request_data() {
    if [[ "$SKIP_WEBSERVER" != "true" ]]; then
        if [[ -n "$DOMAIN" ]]; then
            info "DOMAIN=$DOMAIN"
        else
            while true; do
                question "$(get_string "install_full_node_enter_domain")"
                DOMAIN="$REPLY"
                if [[ "$DOMAIN" == "n" || "$DOMAIN" == "N" ]]; then
                    SKIP_WEBSERVER=true
                    break
                elif [[ -n "$DOMAIN" ]]; then
                    break
                fi
                warn "$(get_string "install_full_node_domain_empty")"
            done
        fi
    fi

    if [[ "$SKIP_WEBSERVER" != "true" ]]; then
        if [[ -n "$MONITOR_PORT" ]]; then
            info "MONITOR_PORT=$MONITOR_PORT"
        else
            while true; do
                question "$(get_string "install_full_node_enter_port")"
                MONITOR_PORT="$REPLY"
                MONITOR_PORT=${MONITOR_PORT:-8443}
                if [[ "$MONITOR_PORT" =~ ^[0-9]+$ ]]; then
                    break
                fi
                warn "$(get_string "install_full_node_port_must_be_number")"
            done
        fi

        if [[ -n "$WEBSERVER" ]]; then
            info "WEBSERVER=$WEBSERVER"
        else
            echo ""
            info "$(get_string "install_full_node_webserver_choice")"
            echo -e "${BLUE}1. $(get_string "install_full_node_webserver_caddy")${RESET}"
            echo -e "${BLUE}2. $(get_string "install_full_node_webserver_nginx")${RESET}"
            echo ""
            while true; do
                question "$(get_string "install_full_node_webserver_choose")"
                WEBSERVER_CHOICE="$REPLY"
                if [[ "$WEBSERVER_CHOICE" == "1" ]]; then
                    WEBSERVER="caddy"
                    break
                elif [[ "$WEBSERVER_CHOICE" == "2" ]]; then
                    WEBSERVER="nginx"
                    break
                fi
                warn "$(get_string "install_full_node_webserver_invalid")"
            done
        fi

        if [[ "$WEBSERVER" == "nginx" ]]; then
            if [[ -n "$USE_PROXY_PROTOCOL" ]]; then
                info "USE_PROXY_PROTOCOL=$USE_PROXY_PROTOCOL"
            else
                while true; do
                    question "$(get_string "install_nginx_node_use_proxy_protocol")"
                    USE_PROXY_PROTOCOL="$REPLY"
                    if [[ "$USE_PROXY_PROTOCOL" == "y" || "$USE_PROXY_PROTOCOL" == "Y" || "$USE_PROXY_PROTOCOL" == "n" || "$USE_PROXY_PROTOCOL" == "N" ]]; then
                        break
                    fi
                    warn "$(get_string "install_full_node_please_enter_yn")"
                done
            fi

            if [[ -n "$CERT_METHOD" ]]; then
                info "CERT_METHOD=$CERT_METHOD"
            else
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
            fi
        fi
    fi

    if [[ "$SKIP_REMNANODE" != "true" ]]; then
        if [[ -n "$NODE_PORT" ]]; then
            info "NODE_PORT=$NODE_PORT"
        else
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
        fi

        if [[ "$SKIP_REMNANODE" != "true" ]]; then
            if [[ -n "$SECRET_KEY" ]]; then
                info "SECRET_KEY=***"
            else
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
    fi

    if [[ "$SKIP_WARP" != "true" ]]; then
        if [[ "$INSTALL_WARP" == "y" || "$INSTALL_WARP" == "Y" ]]; then
            info "INSTALL_WARP=$INSTALL_WARP"
        elif [[ "$INSTALL_WARP" == "n" || "$INSTALL_WARP" == "N" ]]; then
            SKIP_WARP=true
            info "INSTALL_WARP=$INSTALL_WARP, skipping..."
        else
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
    fi

    if [[ "$SKIP_BBR" != "true" ]]; then
        if [[ "$BBR_ANSWER" == "y" || "$BBR_ANSWER" == "Y" ]]; then
            SKIP_BBR=false
            info "BBR_ANSWER=$BBR_ANSWER"
        elif [[ "$BBR_ANSWER" == "n" || "$BBR_ANSWER" == "N" ]]; then
            SKIP_BBR=true
            info "BBR_ANSWER=$BBR_ANSWER, skipping..."
        else
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

    if command -v nginx >/dev/null 2>&1; then
        info "$(get_string "install_full_node_nginx_detected_stopping")"
        systemctl stop nginx 2>/dev/null || true
        systemctl disable nginx 2>/dev/null || true
    fi

    systemctl restart caddy
    success "$(get_string "install_full_node_caddy_installed_success")"
}

install_nginx_selfsteal() {
    info "$(get_string "install_full_node_installing_nginx")"

    if command -v caddy >/dev/null 2>&1; then
        warn "$(get_string "install_nginx_node_caddy_detected")"
        systemctl stop caddy 2>/dev/null || true
        systemctl disable caddy 2>/dev/null || true
        success "$(get_string "install_nginx_node_caddy_stopped")"
    fi

    apt-get install -y nginx certbot

    info "$(get_string "install_full_node_setup_site")"

    if [ -d "/var/www/site" ]; then
        rm -rf /var/www/site/*
    else
        mkdir -p /var/www/site
    fi
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

    local base_domain
    base_domain=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
    local wildcard_domain="*.$base_domain"

    case $CERT_METHOD in
        1)
            if [[ -n "$CF_API_KEY" ]]; then
                info "CF_API_KEY=***"
            else
                while true; do
                    question "$(get_string "install_nginx_node_enter_cf_token")"
                    CF_API_KEY="$REPLY"
                    if [[ -n "$CF_API_KEY" ]]; then break; fi
                    warn "$(get_string "install_nginx_node_token_empty")"
                done
            fi
            if [[ -n "$CF_EMAIL" ]]; then
                info "CF_EMAIL=$CF_EMAIL"
            else
                while true; do
                    question "$(get_string "install_nginx_node_enter_cf_email")"
                    CF_EMAIL="$REPLY"
                    if [[ -n "$CF_EMAIL" ]]; then break; fi
                    warn "$(get_string "install_nginx_node_email_empty")"
                done
            fi

            apt-get install -y python3-certbot-dns-cloudflare

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
            if [[ -n "$LE_EMAIL" ]]; then
                info "LE_EMAIL=$LE_EMAIL"
            else
                while true; do
                    question "$(get_string "install_nginx_node_enter_email")"
                    LE_EMAIL="$REPLY"
                    if [[ -n "$LE_EMAIL" ]]; then break; fi
                    warn "$(get_string "install_nginx_node_email_empty")"
                done
            fi

            systemctl stop nginx 2>/dev/null || true

            certbot certonly \
                --standalone \
                -d "$DOMAIN" \
                --email "$LE_EMAIL" \
                --agree-tos \
                --non-interactive \
                --key-type ecdsa \
                --elliptic-curve secp384r1 || {
                error "$(get_string "install_nginx_node_cert_failed")"
                exit 1
            }
            CERT_DOMAIN="$DOMAIN"
            ;;
        3)
            if [[ -n "$GCORE_API_KEY" ]]; then
                info "GCORE_API_KEY=***"
            else
                while true; do
                    question "$(get_string "install_nginx_node_enter_gcore_token")"
                    GCORE_API_KEY="$REPLY"
                    if [[ -n "$GCORE_API_KEY" ]]; then break; fi
                    warn "$(get_string "install_nginx_node_token_empty")"
                done
            fi
            if [[ -n "$LE_EMAIL" ]]; then
                info "LE_EMAIL=$LE_EMAIL"
            else
                while true; do
                    question "$(get_string "install_nginx_node_enter_email")"
                    LE_EMAIL="$REPLY"
                    if [[ -n "$LE_EMAIL" ]]; then break; fi
                    warn "$(get_string "install_nginx_node_email_empty")"
                done
            fi

            if ! certbot plugins 2>/dev/null | grep -q "dns-gcore"; then
                info "$(get_string "install_nginx_node_installing_gcore_plugin")"
                apt-get install -y python3-pip >/dev/null 2>&1
                if python3 -m pip install --help 2>&1 | grep -q "break-system-packages"; then
                    python3 -m pip install --break-system-packages certbot-dns-gcore
                else
                    python3 -m pip install certbot-dns-gcore
                fi

                if ! certbot plugins 2>/dev/null | grep -q "dns-gcore"; then
                    error "$(get_string "install_nginx_node_gcore_plugin_failed")"
                    exit 1
                fi
                success "$(get_string "install_nginx_node_gcore_plugin_installed")"
            else
                info "$(get_string "install_nginx_node_gcore_plugin_exists")"
            fi

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

    if ! crontab -u root -l 2>/dev/null | grep -q "/usr/bin/certbot renew"; then
        local cron_command
        if [ "$CERT_METHOD" == "2" ]; then
            cron_command="systemctl stop nginx && /usr/bin/certbot renew --quiet && systemctl start nginx"
        else
            cron_command="/usr/bin/certbot renew --quiet && systemctl reload nginx"
        fi
        (crontab -u root -l 2>/dev/null; echo "0 5 * * 0 $cron_command") | crontab -u root -
    fi

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
    success "$(get_string "install_full_node_nginx_installed_success")"
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
    while fuser /var/lib/apt/lists/lock /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        warn "apt is locked by another process, waiting..."
        sleep 3
    done
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
    
    if [[ "$SKIP_WEBSERVER" != "true" ]]; then
        if [[ "$WEBSERVER" == "caddy" ]]; then
            if [[ "$UPDATE_CADDY" == "true" ]]; then
                systemctl stop caddy
                rm -f /etc/caddy/Caddyfile
            fi
            install_caddy
        elif [[ "$WEBSERVER" == "nginx" ]]; then
            if [[ "$UPDATE_NGINX" == "true" ]]; then
                systemctl stop nginx 2>/dev/null || true
                rm -f /etc/nginx/conf.d/selfsteal.conf
            fi
            install_nginx_selfsteal
        fi
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

    if [[ "$WEBSERVER" == "nginx" && "$SKIP_WEBSERVER" != "true" ]]; then
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
    fi

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
