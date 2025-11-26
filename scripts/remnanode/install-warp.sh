#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

RESTORE_DNS_REQUIRED=false

restore_dns() {
    if [[ "$RESTORE_DNS_REQUIRED" == true && -f /etc/resolv.conf.backup ]]; then
        cp /etc/resolv.conf.backup /etc/resolv.conf
        success "$(get_string "warp_native_dns_restored")"
        RESTORE_DNS_REQUIRED=false
    fi
}

trap restore_dns EXIT

check_warp_native() {
    if command -v wgcf >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
        info "$(get_string "warp_native_already_installed")"
        while true; do
            question "$(get_string "warp_native_reconfigure")"
            RECONFIGURE="$REPLY"
            if [[ "$RECONFIGURE" == "y" || "$RECONFIGURE" == "Y" ]]; then
                return 0
            elif [[ "$RECONFIGURE" == "n" || "$RECONFIGURE" == "N" ]]; then
                info "$(get_string "warp_native_skip_installation")"
                read -n 1 -s -r -p "$(get_string "warp_native_press_key")"
                exit 0
            else
                warn "$(get_string "warp_native_please_enter_yn")"
            fi
        done
    fi
    return 0
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

install_warp_native() {
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
    echo ""
    echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_check_service"):${RESET} systemctl status wg-quick@warp"
    echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_show_info"):${RESET} wg show warp"
    echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_stop_interface"):${RESET} systemctl stop wg-quick@warp"
    echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_start_interface"):${RESET} systemctl start wg-quick@warp"
    echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_restart_interface"):${RESET} systemctl restart wg-quick@warp"
    echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_disable_autostart"):${RESET} systemctl disable wg-quick@warp"
    echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_enable_autostart_cmd"):${RESET} systemctl enable wg-quick@warp"
    echo ""
}

main() {
    if ! check_warp_native; then
        return 0
    fi

    if command -v wgcf >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
        uninstall_warp_native
        echo ""
    fi

    install_warp_native
    read -n 1 -s -r -p "$(get_string "warp_native_press_key")"
    exit 0
}

main
