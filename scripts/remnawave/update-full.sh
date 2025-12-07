#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

update_all() {
    info "$(get_string update_full_updating)"
    
    cd /opt/remnawave
    docker compose pull
    docker compose down
    docker compose up -d

    cd /opt/remnawave/subscription
    docker compose pull
    docker compose down
    docker compose up -d
    
    success "$(get_string update_full_complete)"
}

main() {
    update_all
    read -n 1 -s -r -p "$(get_string update_full_press_key)"
    exit 0
}

main
