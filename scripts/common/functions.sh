#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

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

menu() {
    echo -e "${BOLD_MAGENTA}$1${RESET}"
    read -p "$(echo -e "${BOLD_CYAN}$(get_string "select_menu_option"):${RESET}") " choice
    echo "$choice"
}

question() {
    read -p "$(echo -e "${BOLD_CYAN}$1${RESET}") " REPLY
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        error "$(get_string "root_required")"
        exit 1
    fi
}

check_directory() {
    if [ ! -d "$1" ]; then
        error "$(get_string "directory_not_exist" "$1")"
        exit 1
    fi
}

check_file() {
    if [ ! -f "$1" ]; then
        error "$(get_string "file_not_exist" "$1")"
        exit 1
    fi
}

create_directory() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

backup_file() {
    if [ -f "$1" ]; then
        cp "$1" "$1.bak"
    fi
}

restore_file() {
    if [ -f "$1.bak" ]; then
        mv "$1.bak" "$1"
    fi
}

detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v apk &> /dev/null; then
        echo "apk"
    else
        echo "unknown"
    fi
}

update_package_list() {
    local pm=$(detect_package_manager)
    case "$pm" in
        apt)
            apt-get update -y
            ;;
        yum)
            yum check-update -y || true
            ;;
        dnf)
            dnf check-update -y || true
            ;;
        apk)
            apk update
            ;;
        *)
            error "Unsupported package manager"
            return 1
            ;;
    esac
}

install_packages() {
    local pm=$(detect_package_manager)
    local packages="$@"
    
    case "$pm" in
        apt)
            apt-get install -y $packages
            ;;
        yum)
            yum install -y $packages
            ;;
        dnf)
            dnf install -y $packages
            ;;
        apk)
            apk add --no-cache $packages
            ;;
        *)
            error "Unsupported package manager"
            return 1
            ;;
    esac
}

ensure_package() {
    local package="$1"
    if command_exists "$package"; then
        return 0
    fi

    local install_name="$package"
    case "$package" in
        7z)
            local pm=$(detect_package_manager)
            if [ "$pm" = "apt" ]; then
                install_name="p7zip-full"
            else
                install_name="p7zip"
            fi
            ;;
    esac
    
    info "Installing $install_name..."
    update_package_list
    install_packages "$install_name"
}

export -f info
export -f warn
export -f error
export -f success
export -f menu
export -f question
export -f command_exists
export -f check_root
export -f check_directory
export -f check_file
export -f create_directory
export -f backup_file
export -f restore_file
export -f detect_package_manager
export -f update_package_list
export -f install_packages
export -f ensure_package
