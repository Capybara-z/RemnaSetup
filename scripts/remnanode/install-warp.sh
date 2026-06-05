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

        if [[ "$RECONFIGURE" == "y" || "$RECONFIGURE" == "Y" || "$RECONFIGURE" == "true" ]]; then
            info "RECONFIGURE=$RECONFIGURE, will reinstall..."
            return 0
        fi

        if [[ "$RECONFIGURE" == "n" || "$RECONFIGURE" == "N" || "$RECONFIGURE" == "false" ]]; then
            info "RECONFIGURE=$RECONFIGURE, skipping..."
            pause_press_key "$(get_string "warp_native_press_key")"
            exit 0
        fi

        if is_non_interactive; then
            info "Non-interactive mode: RECONFIGURE not set, skipping reinstall."
            pause_press_key "$(get_string "warp_native_press_key")"
            exit 0
        fi

        while true; do
            question "$(get_string "warp_native_reconfigure")"
            RECONFIGURE="$REPLY"
            if [[ "$RECONFIGURE" == "y" || "$RECONFIGURE" == "Y" ]]; then
                return 0
            elif [[ "$RECONFIGURE" == "n" || "$RECONFIGURE" == "N" ]]; then
                info "$(get_string "warp_native_skip_installation")"
                pause_press_key "$(get_string "warp_native_press_key")"
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

    info "$(get_string "warp_native_removing_watchdog")"
    rm -f /etc/cron.d/warp-native &>/dev/null
    rm -rf /opt/warp-native &>/dev/null

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

    if command -v wget &>/dev/null; then
        wget -q "$WGCF_DOWNLOAD_URL" -O "$WGCF_BINARY_NAME" || {
            error "$(get_string "warp_native_wgcf_download_failed")"
            exit 1
        }
    elif command -v curl &>/dev/null; then
        curl -sL "$WGCF_DOWNLOAD_URL" -o "$WGCF_BINARY_NAME" || {
            error "$(get_string "warp_native_wgcf_download_failed")"
            exit 1
        }
    else
        error "$(get_string "warp_native_wgcf_download_failed")"
        exit 1
    fi

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
            timeout 60 bash -c 'yes | wgcf register' &>/dev/null || true
            
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
    sed -i 's/,\s*[0-9a-fA-F:]\+\/128//' /etc/wireguard/warp.conf
    sed -i '/Address = [0-9a-fA-F:]\+\/128/d' /etc/wireguard/warp.conf
    success "$(get_string "warp_native_ipv6_removed")"
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

    handshake_ts=0
    for i in {1..10}; do
        handshake_ts=$(wg show warp latest-handshakes 2>/dev/null | awk '{print $2}')
        if [[ -n "$handshake_ts" && "$handshake_ts" -gt 0 ]]; then
            age=$(( $(date +%s) - handshake_ts ))
            success "$(get_string "warp_native_handshake_received") ${age}s ago"
            success "$(get_string "warp_native_warp_active")"
            break
        fi
        sleep 1
    done

    if [[ -z "$handshake_ts" || "$handshake_ts" -eq 0 ]]; then
        warn "$(get_string "warp_native_handshake_failed")"
    fi

    curl_result=$(curl -s --interface warp --max-time 5 https://www.cloudflare.com/cdn-cgi/trace | grep "warp=" | cut -d= -f2)

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

    info "$(get_string "warp_native_setup_watchdog")"

    mkdir -p /opt/warp-native/logs || {
        error "$(get_string "warp_native_watchdog_dir_failed")"
        exit 1
    }

    cat > /opt/warp-native/config.env <<EOF
# warp-native watchdog configuration
# Edited values take effect on next cron run

# Handshake threshold in seconds (default: 180)
HANDSHAKE_THRESHOLD=180

# Cooldown between restarts in seconds (default: 120)
RESTART_COOLDOWN=120

# Max log lines before rotation (default: 1000)
LOG_MAX_LINES=1000
EOF

    cat > /opt/warp-native/warp-watchdog.sh <<'WATCHDOG_EOF'
#!/bin/bash

CONFIG="/opt/warp-native/config.env"
LOG="/opt/warp-native/logs/watchdog.log"
COOLDOWN_FILE="/opt/warp-native/logs/.last_restart"

if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

HANDSHAKE_THRESHOLD="${HANDSHAKE_THRESHOLD:-180}"
RESTART_COOLDOWN="${RESTART_COOLDOWN:-120}"
LOG_MAX_LINES="${LOG_MAX_LINES:-1000}"

log() {
    local level="$1"
    local message="$2"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $message" >> "$LOG"
}

rotate_log() {
    if [[ -f "$LOG" ]]; then
        local lines
        lines=$(wc -l < "$LOG")
        if [[ $lines -gt $LOG_MAX_LINES ]]; then
            tail -n "$LOG_MAX_LINES" "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
        fi
    fi
}

do_restart() {
    local reason="$1"

    if [[ -f "$COOLDOWN_FILE" ]]; then
        local last_restart
        last_restart=$(cat "$COOLDOWN_FILE")
        local now
        now=$(date +%s)
        local diff=$(( now - last_restart ))
        if [[ $diff -lt $RESTART_COOLDOWN ]]; then
            log "SKIP" "Restart skipped (cooldown: ${diff}s < ${RESTART_COOLDOWN}s). Reason was: $reason"
            return
        fi
    fi

    log "RESTART" "Restarting wg-quick@warp. Reason: $reason"
    systemctl restart wg-quick@warp
    local ret=$?
    date +%s > "$COOLDOWN_FILE"

    if [[ $ret -eq 0 ]]; then
        log "OK" "wg-quick@warp restarted successfully"
    else
        log "ERROR" "Failed to restart wg-quick@warp (exit code: $ret)"
    fi
}

rotate_log

if ! systemctl is-active --quiet wg-quick@warp; then
    do_restart "systemd unit is not active"
    exit 0
fi

handshake_ts=$(wg show warp latest-handshakes 2>/dev/null | awk '{print $2}')

if [[ -z "$handshake_ts" || "$handshake_ts" -eq 0 ]]; then
    do_restart "no handshake data"
    exit 0
fi

now=$(date +%s)
age=$(( now - handshake_ts ))

if [[ $age -gt $HANDSHAKE_THRESHOLD ]]; then
    do_restart "handshake too old (${age}s > ${HANDSHAKE_THRESHOLD}s)"
    exit 0
fi

if ! ping -I warp -c 2 -W 3 1.1.1.1 &>/dev/null; then
    do_restart "ping via warp interface failed"
    exit 0
fi

log "OK" "WARP is healthy (handshake: ${age}s ago)"
WATCHDOG_EOF

    chmod +x /opt/warp-native/warp-watchdog.sh
    success "$(get_string "warp_native_watchdog_created")"

    cat > /etc/cron.d/warp-native <<'EOF'
# warp-native watchdog — checks WARP tunnel health every 10 minutes
*/10 * * * * root /opt/warp-native/warp-watchdog.sh
EOF

    chmod 644 /etc/cron.d/warp-native
    success "$(get_string "warp_native_watchdog_cron_set")"
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
    echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_watchdog_log"):${RESET} tail -f /opt/warp-native/logs/watchdog.log"
    echo -e "${BOLD_CYAN}➤ $(get_string "warp_native_watchdog_config"):${RESET} nano /opt/warp-native/config.env"
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
    pause_press_key "$(get_string "warp_native_press_key")"
    exit 0
}

main
