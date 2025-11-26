#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

check_ipv6_status() {
    if sysctl net.ipv6.conf.all.disable_ipv6 | grep -q "= 1"; then
        return 1
    else
        return 0
    fi
}

disable_ipv6() {
    info "$(get_string "ipv6_disabling")"
    
    tee -a /etc/sysctl.conf > /dev/null << EOF

# IPv6 Disable
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    if [ -d "/proc/sys/net/ipv6/conf/tun0" ]; then
        echo "net.ipv6.conf.tun0.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
    fi

    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=1
    
    if [ -d "/proc/sys/net/ipv6/conf/tun0" ]; then
        sysctl -w net.ipv6.conf.tun0.disable_ipv6=1
    fi
    
    success "$(get_string "ipv6_disabled_success")"
}

enable_ipv6() {
    info "$(get_string "ipv6_enabling")"

    sed -i '/^# IPv6 Disable$/,/^net\.ipv6\.conf\..*\.disable_ipv6 = 1$/d' /etc/sysctl.conf

    sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sysctl -w net.ipv6.conf.default.disable_ipv6=0
    sysctl -w net.ipv6.conf.lo.disable_ipv6=0
    
    if [ -d "/proc/sys/net/ipv6/conf/tun0" ]; then
        sysctl -w net.ipv6.conf.tun0.disable_ipv6=0
    fi
    
    success "$(get_string "ipv6_enabled_success")"
}

main() {
    if check_ipv6_status; then
        echo -e "${GREEN}[INFO] $(get_string "ipv6_status_enabled")${RESET}"
        while true; do
            question "$(get_string "ipv6_disable_confirm")"
            if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
                disable_ipv6
                break
            elif [[ "$REPLY" == "n" || "$REPLY" == "N" ]]; then
                info "$(get_string "ipv6_operation_cancelled")"
                break
            else
                warn "$(get_string "install_full_node_please_enter_yn")"
            fi
        done
    else
        echo -e "${RED}[INFO] $(get_string "ipv6_status_disabled")${RESET}"
        while true; do
            question "$(get_string "ipv6_enable_confirm")"
            if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
                enable_ipv6
                break
            elif [[ "$REPLY" == "n" || "$REPLY" == "N" ]]; then
                info "$(get_string "ipv6_operation_cancelled")"
                break
            else
                warn "$(get_string "install_full_node_please_enter_yn")"
            fi
        done
    fi
    
    read -n 1 -s -r -p "$(get_string "press_any_key")"
    exit 0
}

main 