#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

update_panel() {
    info "$(get_string "update_node_updating")"
    cd /opt/remnanode
    docker compose pull
    docker compose down
    docker compose up -d
}

main() {
    update_panel
    success "$(get_string "update_node_complete")"
    pause_press_key "$(get_string "update_node_press_key")"
    exit 0
}

main
