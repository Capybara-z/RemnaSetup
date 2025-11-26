#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

check_bbr() {
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        info "$(get_string "install_bbr_already_configured")"
        read -n 1 -s -r -p "$(get_string "install_bbr_press_key")"
        exit 0
        return 1
    fi
    return 0
}

install_bbr() {
    info "$(get_string "install_bbr_installing")"
    echo "net.core.default_qdisc=fq" | tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" | tee -a /etc/sysctl.conf
    sysctl -p
    success "$(get_string "install_bbr_installed")"
}

main() {
    if ! check_bbr; then
        return 0
    fi

    install_bbr
    read -n 1 -s -r -p "$(get_string "install_bbr_press_key")"
    exit 0
}

main
