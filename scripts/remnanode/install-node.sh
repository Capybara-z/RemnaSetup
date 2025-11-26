#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

check_docker() {
    if command -v docker >/dev/null 2>&1; then
        info "$(get_string "install_node_docker_installed")"
        return 0
    else
        return 1
    fi
}

install_docker() {
    info "$(get_string "install_node_installing_docker")"
    curl -fsSL https://get.docker.com | sh || {
        error "$(get_string "install_node_docker_error")"
        exit 1
    }
    success "$(get_string "install_node_docker_success")"
}

setup_logs_and_logrotate() {
    info "$(get_string "install_node_setup_logs")"

    if [ ! -d "/var/log/remnanode" ]; then
        mkdir -p /var/log/remnanode
        chmod -R 777 /var/log/remnanode
        info "$(get_string "install_node_logs_dir_created")"
    else
        info "$(get_string "install_node_logs_dir_exists")"
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
        success "$(get_string "install_node_logs_configured")"
    else
        info "$(get_string "install_node_logs_already_configured")"
    fi
}

check_remnanode() {
    if [ -f "/opt/remnanode/docker-compose.yml" ]; then
        info "$(get_string "install_node_already_installed")"
        while true; do
            question "$(get_string "install_node_update_settings")"
            REINSTALL="$REPLY"
            if [[ "$REINSTALL" == "y" || "$REINSTALL" == "Y" ]]; then
                return 0
            elif [[ "$REINSTALL" == "n" || "$REINSTALL" == "N" ]]; then
                info "$(get_string "install_node_already_installed")"
                read -n 1 -s -r -p "$(get_string "install_node_press_key")"
                exit 0
                return 1
            else
                warn "$(get_string "install_node_please_enter_yn")"
            fi
        done
    fi
    return 0
}

install_remnanode() {
    info "$(get_string "install_node_installing")"
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

    echo "NODE_PORT=$NODE_PORT" > .env
    echo "SECRET_KEY=$SECRET_KEY" >> .env

    cp "/opt/remnasetup/data/docker/node-compose.yml" docker-compose.yml

    docker compose up -d || {
        error "$(get_string "install_node_error")"
        exit 1
    }
    success "$(get_string "install_node_success")"
}

main() {
    if check_remnanode; then
        cd /opt/remnanode
        docker compose down
    fi

    while true; do
        question "$(get_string "install_node_enter_app_port")"
        NODE_PORT="$REPLY"
        NODE_PORT=${NODE_PORT:-3001}
        if [[ "$NODE_PORT" =~ ^[0-9]+$ ]]; then
            break
        fi
        warn "$(get_string "install_node_port_must_be_number")"
    done

    while true; do
        question "$(get_string "install_node_enter_ssl_cert")"
        SECRET_KEY="$REPLY"
        if [[ -n "$SECRET_KEY" ]]; then
            break
        fi
        warn "$(get_string "install_node_ssl_cert_empty")"
    done

    if ! check_docker; then
        install_docker
    fi

    setup_logs_and_logrotate

    install_remnanode

    success "$(get_string "install_node_complete")"
    read -n 1 -s -r -p "$(get_string "install_node_press_key")"
    exit 0
}

main 
