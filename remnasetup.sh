#!/bin/bash

SCRIPT_DIR="/opt/remnasetup"

. /opt/remnasetup/scripts/common/colors.sh
. /opt/remnasetup/scripts/common/functions.sh
. /opt/remnasetup/scripts/common/languages.sh

menu() {
    echo -e "${BOLD_MAGENTA}$1${RESET}"
}

question() {
    echo -e "${BOLD_CYAN}$1${RESET}"
}

info() {
    echo -e "${BOLD_CYAN}[INFO]${RESET} $1"
}

warn() {
    echo -e "${BOLD_YELLOW}[WARN]${RESET} $1"
}

error() {
    echo -e "${BOLD_RED}[ERROR]${RESET} $1"
}

success() {
    echo -e "${BOLD_GREEN}[SUCCESS]${RESET} $1"
}

print_header() {
    clear
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"
    echo -e "\033[1;32m"
    echo -e "┌───────────────────────────────────────────────────────────────────┐"
    echo -e "│  ██████╗ █████╗ ██████╗ ██╗   ██╗██████╗  █████╗ ██████╗  █████╗  │"
    echo -e "│ ██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗ │"
    echo -e "│ ██║     ███████║██████╔╝ ╚████╔╝ ██████╔╝███████║██████╔╝███████║ │"
    echo -e "│ ██║     ██╔══██║██╔═══╝   ╚██╔╝  ██╔══██╗██╔══██║██╔══██╗██╔══██║ │"
    echo -e "│ ╚██████╗██║  ██║██║        ██║   ██████╔╝██║  ██║██║  ██║██║  ██║ │"
    echo -e "│  ╚═════╝╚═╝  ╚═╝╚═╝        ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ │"
    echo -e "└───────────────────────────────────────────────────────────────────┘"
    echo -e "\033[0m"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"
    if [ "$LANGUAGE" = "en" ]; then
        echo -e "${GREEN}RemnaSetup by capybara${RESET}"
        echo -e "${CYAN}Project: https://github.com/Capybara-z/RemnaSetup${RESET}"
        echo -e "${YELLOW}Contacts: @KaTTuBaRa${RESET}"
        echo -e "${CYAN}Version: 2.5${RESET}"
        echo
        echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"
        echo -e "${YELLOW}Made with support from:${RESET}"
        echo -e "${CYAN}GitHub SoloBot: https://github.com/Vladless/Solo_bot${RESET}"
        echo -e "${YELLOW}Contacts: @solonet_sup${RESET}"
    else
        echo -e "${GREEN}RemnaSetup by capybara${RESET}"
        echo -e "${CYAN}Проект: https://github.com/Capybara-z/RemnaSetup${RESET}"
        echo -e "${YELLOW}Контакты: @KaTTuBaRa${RESET}"
        echo -e "${CYAN}Версия: 2.5${RESET}"
        echo
        echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"
        echo -e "${YELLOW}Сделано при поддержке проекта:${RESET}"
        echo -e "${CYAN}GitHub SoloBot: https://github.com/Vladless/Solo_bot${RESET}"
        echo -e "${YELLOW}Контакты: @solonet_sup${RESET}"
    fi
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${RESET}"
    echo
}

display_remnawave_menu() {
    clear
    print_header
    menu "$(get_string "remnawave_menu")"
    if [ "$LANGUAGE" = "en" ]; then
        echo -e "${BLUE}1. Full installation (Remnawave + Caddy)${RESET}"
        echo -e "${BLUE}2. Install Remnawave${RESET}"
        echo -e "${BLUE}3. Install Subscription Page${RESET}"
        echo -e "${BLUE}4. Install Caddy${RESET}"
        echo -e "${BLUE}5. Update (Remnawave + Subscription Page)${RESET}"
        echo -e "${BLUE}6. Update Remnawave${RESET}"
        echo -e "${BLUE}7. Update Subscription Page${RESET}"
        echo -e "${BLUE}8. Back${RESET}"
    else
        echo -e "${BLUE}1. Полная установка (Remnawave + Caddy)${RESET}"
        echo -e "${BLUE}2. Установка Remnawave${RESET}"
        echo -e "${BLUE}3. Установка Страницы подписок${RESET}"
        echo -e "${BLUE}4. Установка Caddy${RESET}"
        echo -e "${BLUE}5. Обновление (Remnawave + Страницы подписок)${RESET}"
        echo -e "${BLUE}6. Обновление Remnawave${RESET}"
        echo -e "${BLUE}7. Обновление Страницы подписок${RESET}"
        echo -e "${BLUE}8. Назад${RESET}"
    fi
    echo
    read -p "$(echo -e "${BOLD_CYAN}$(get_string "select_option"):${RESET}") " REMNAWAVE_OPTION
    echo
}

display_remnanode_menu() {
    clear
    print_header
    menu "$(get_string "remnanode_menu")"
    if [ "$LANGUAGE" = "en" ]; then
        echo -e "${BLUE}1. Full installation (Remnanode + Caddy + BBR + WARP-NATIVE (by distillium))${RESET}"
        echo -e "${BLUE}2. Install Remnanode only${RESET}"
        echo -e "${BLUE}3. Install Caddy + self-steal only${RESET}"
        echo -e "${BLUE}4. IPv6 Management${RESET}"
        echo -e "${BLUE}5. Install BBR only${RESET}"
        echo -e "${BLUE}6. Install WARP-NATIVE (by distillium)${RESET}"
        echo -e "${BLUE}7. Update Remnanode${RESET}"
        echo -e "${BLUE}8. Back${RESET}"
    else
        echo -e "${BLUE}1. Полная установка (Remnanode + Caddy + BBR + WARP-NATIVE (by distillium))${RESET}"
        echo -e "${BLUE}2. Только Remnanode${RESET}"
        echo -e "${BLUE}3. Только Caddy + self-steal${RESET}"
        echo -e "${BLUE}4. Управление IPv6${RESET}"
        echo -e "${BLUE}5. Только BBR${RESET}"
        echo -e "${BLUE}6. Установить WARP-NATIVE (by distillium)${RESET}"
        echo -e "${BLUE}7. Обновить Remnanode${RESET}"
        echo -e "${BLUE}8. Назад${RESET}"
    fi
    echo
    read -p "$(echo -e "${BOLD_CYAN}$(get_string "select_option"):${RESET}") " REMNANODE_OPTION
    echo
}

display_backup_menu() {
    clear
    print_header
    menu "$(get_string "backup_menu")"
    if [ "$LANGUAGE" = "en" ]; then
        echo -e "${BLUE}1. Create Remnawave backup${RESET}"
        echo -e "${BLUE}2. Restore from Remnawave backup${RESET}"
        echo -e "${BLUE}3. Configure automatic backup${RESET}"
        echo -e "${RED}0. Exit${RESET}"
    else
        echo -e "${BLUE}1. Создать резервную копию Remnawave${RESET}"
        echo -e "${BLUE}2. Восстановить из резервной копии Remnawave${RESET}"
        echo -e "${BLUE}3. Настроить автоматическое резервное копирование${RESET}"
        echo -e "${RED}0. Выход${RESET}"
    fi
    echo
    read -p "$(echo -e "${BOLD_CYAN}$(get_string "select_option"):${RESET}") " BACKUP_OPTION
    echo
}

display_main_menu() {
    clear
    print_header
    menu "$(get_string "main_menu")"
    if [ "$LANGUAGE" = "en" ]; then
        echo -e "${BLUE}1. Install/Update Remnawave${RESET}"
        echo -e "${BLUE}2. Install/Update Remnanode${RESET}"
        echo -e "${BLUE}3. Remnawave Backup and Restore${RESET}"
        echo -e "${RED}0. Exit${RESET}"
    else
        echo -e "${BLUE}1. Установка/Обновление Remnawave${RESET}"
        echo -e "${BLUE}2. Установка/Обновление Remnanode${RESET}"
        echo -e "${BLUE}3. Резервное копирование и восстановление Remnawave${RESET}"
        echo -e "${RED}0. Выход${RESET}"
    fi
    echo
    read -p "$(echo -e "${BOLD_CYAN}$(get_string "select_option"):${RESET}") " MAIN_OPTION
    echo
}

run_script() {
    local script="$1"
    if [ -f "$script" ]; then
        bash "$script"
        local result=$?
        if [ $result -ne 0 ]; then
            warn "$(get_string "script_error")"
            read -n 1 -s -r -p "$(get_string "press_any_key")"
        fi
    else
        error "$(get_string "script_not_found"): $script"
        read -n 1 -s -r -p "$(get_string "press_any_key")"
    fi
}

main() {
    select_language
    while true; do
        display_main_menu
        case $MAIN_OPTION in
            1)
                while true; do
                    display_remnawave_menu
                    case $REMNAWAVE_OPTION in
                        1) run_script "${SCRIPT_DIR}/scripts/remnawave/install-full.sh" ;;
                        2) run_script "${SCRIPT_DIR}/scripts/remnawave/install-panel.sh" ;;
                        3) run_script "${SCRIPT_DIR}/scripts/remnawave/install-subscription.sh" ;;
                        4) run_script "${SCRIPT_DIR}/scripts/remnawave/install-caddy.sh" ;;
                        5) run_script "${SCRIPT_DIR}/scripts/remnawave/update-full.sh" ;;
                        6) run_script "${SCRIPT_DIR}/scripts/remnawave/update-panel.sh" ;;
                        7) run_script "${SCRIPT_DIR}/scripts/remnawave/update-subscription.sh" ;;
                        8) break ;;
                        *) warn "$(get_string "invalid_choice")" ;;
                    esac
                done
                ;;
            2)
                while true; do
                    display_remnanode_menu
                    case $REMNANODE_OPTION in
                        1) run_script "${SCRIPT_DIR}/scripts/remnanode/install-full.sh" ;;
                        2) run_script "${SCRIPT_DIR}/scripts/remnanode/install-node.sh" ;;
                        3) run_script "${SCRIPT_DIR}/scripts/remnanode/install-caddy.sh" ;;
                        4) run_script "${SCRIPT_DIR}/scripts/remnanode/install-ipv6.sh" ;;
                        5) run_script "${SCRIPT_DIR}/scripts/remnanode/install-bbr.sh" ;;
                        6) run_script "${SCRIPT_DIR}/scripts/remnanode/install-warp.sh" ;;
                        7) run_script "${SCRIPT_DIR}/scripts/remnanode/update.sh" ;;
                        8) break ;;
                        *) warn "$(get_string "invalid_choice")" ;;
                    esac
                done
                ;;
            3)
                while true; do
                    display_backup_menu
                    case $BACKUP_OPTION in
                        1) run_script "${SCRIPT_DIR}/scripts/backups/backup.sh" ;;
                        2) run_script "${SCRIPT_DIR}/scripts/backups/restore.sh" ;;
                        3) run_script "${SCRIPT_DIR}/scripts/backups/auto_backup.sh" ;;
                        0) break ;;
                        *) warn "$(get_string "invalid_choice")" ;;
                    esac
                done
                ;;
            0)
                info "$(get_string "exiting")"
                echo -e "${RESET}"
                exit 0
                ;;
            *)
                warn "$(get_string "invalid_choice")"
                ;;
        esac
    done
}

main 
