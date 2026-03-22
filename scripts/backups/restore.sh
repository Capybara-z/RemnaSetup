#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

BACKUP_DIR="/opt/backups"
WORK_DIR="$BACKUP_DIR/restore_work"
DATE=$(date +%F_%H-%M-%S)
DB_VOLUME="remnawave-db-data"
REDIS_VOLUME="remnawave-redis-data"
REMWAVE_DIR="/opt/remnawave"
PANEL_CONTAINER="remnawave"
DB_CONTAINER="remnawave-db"

info "$(get_string "restore_start")"

get_telegram_backups() {
    local bot_token=$1
    local chat_id=$2
    local temp_file="/tmp/telegram_backups.json"

    curl -s "https://api.telegram.org/bot${bot_token}/getUpdates?chat_id=${chat_id}&limit=5" > "$temp_file"

    local backups=()
    while IFS= read -r line; do
        if [[ $line =~ remnawave-backup-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.7z ]]; then
            backups+=("$line")
        fi
    done < <(jq -r '.result[].message.document.file_name' "$temp_file" 2>/dev/null)
    
    rm -f "$temp_file"
    echo "${backups[@]}"
}

download_telegram_backup() {
    local bot_token=$1
    local chat_id=$2
    local file_name=$3
    local temp_file="/tmp/telegram_file.json"

    curl -s "https://api.telegram.org/bot${bot_token}/getUpdates?chat_id=${chat_id}&limit=5" > "$temp_file"
    local file_id=$(jq -r --arg name "$file_name" '.result[].message.document | select(.file_name == $name) | .file_id' "$temp_file")
    
    if [ -n "$file_id" ]; then
        local file_path=$(curl -s "https://api.telegram.org/bot${bot_token}/getFile?file_id=${file_id}" | jq -r '.result.file_path')
        curl -s "https://api.telegram.org/file/bot${bot_token}/${file_path}" -o "$BACKUP_DIR/$file_name"
        rm -f "$temp_file"
        return 0
    fi
    
    rm -f "$temp_file"
    return 1
}

while true; do
    question "$(get_string "restore_select_source")"
    SOURCE="$REPLY"
    if [[ "$SOURCE" == "y" || "$SOURCE" == "Y" ]]; then
        break
    elif [[ "$SOURCE" == "n" || "$SOURCE" == "N" ]]; then
        break
    else
        warn "$(get_string "restore_please_answer_yn")"
    fi
done

mkdir -p "$BACKUP_DIR"

if [ "$SOURCE" = "telegram" ]; then
    question "$(get_string "restore_enter_bot_token")"
    BOT_TOKEN="$REPLY"
    
    question "$(get_string "restore_enter_chat_id")"
    CHAT_ID="$REPLY"
    
    while true; do
        info "$(get_string "restore_send_backup")"
        read -n 1 -s -r
        info "$(get_string "restore_getting_backups")"
        mapfile -t TG_BACKUPS < <(get_telegram_backups "$BOT_TOKEN" "$CHAT_ID")
        if [ ${#TG_BACKUPS[@]} -eq 0 ]; then
            warn "$(get_string "restore_no_backups")"
        else
            break
        fi
    done
    
    echo "$(get_string "restore_available_backups"):"
    for i in "${!TG_BACKUPS[@]}"; do
        echo "$((i+1)). ${TG_BACKUPS[$i]}"
    done
    
    while true; do
        question "$(get_string "restore_enter_backup_number")"
        if [[ "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY >= 1 && REPLY <= ${#TG_BACKUPS[@]} )); then
            SELECTED_BACKUP="${TG_BACKUPS[$((REPLY-1))]}"
            info "$(get_string "restore_selected_backup" "$SELECTED_BACKUP")"
            break
        else
            warn "$(get_string "restore_invalid_choice")"
        fi
    done
    
    info "$(get_string "restore_downloading_archive")"
    if ! download_telegram_backup "$BOT_TOKEN" "$CHAT_ID" "$SELECTED_BACKUP"; then
        error "$(get_string "restore_download_failed")"
        read -n 1 -s -r -p "$(get_string "restore_press_key")"; exit 1
    fi
    ARCHIVE_PATH="$BACKUP_DIR/$SELECTED_BACKUP"
else
    mapfile -t ARCHIVES < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'remnawave-backup-*.7z' | sort)
    
    if [[ ${#ARCHIVES[@]} -eq 0 ]]; then
        info "$(get_string "restore_no_local_backups" "$BACKUP_DIR")"
        read -n 1 -s -r -p "$(get_string "restore_press_key_continue")"
        echo
        
        while true; do
            mapfile -t ARCHIVES < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'remnawave-backup-*.7z' | sort)
            if [[ ${#ARCHIVES[@]} -eq 0 ]]; then
                warn "$(get_string "restore_no_backups_found" "$BACKUP_DIR")"
                read -n 1 -s KEY
                if [[ "$KEY" == "n" || "$KEY" == "N" ]]; then
                    info "$(get_string "restore_exit")"
                    exit 0
                fi
            else
                break
            fi
        done
    fi
    
    echo "$(get_string "restore_available_local_backups"):"
    for i in "${!ARCHIVES[@]}"; do
        echo "$((i+1)). ${ARCHIVES[$i]}"
    done
    
    while true; do
        question "$(get_string "restore_enter_backup_number")"
        if [[ "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY >= 1 && REPLY <= ${#ARCHIVES[@]} )); then
            ARCHIVE_PATH="${ARCHIVES[$((REPLY-1))]}"
            info "$(get_string "restore_selected_backup" "$ARCHIVE_PATH")"
            break
        else
            warn "$(get_string "restore_invalid_choice")"
        fi
    done
fi

while true; do
    question "$(get_string "restore_enter_password")"
    PASSWORD="$REPLY"
    if [ ${#PASSWORD} -ge 8 ]; then
        break
    else
        warn "$(get_string "restore_password_short")"
    fi
done

if ! command -v docker &>/dev/null; then
    warn "$(get_string "restore_docker_not_found")"
    sudo curl -fsSL https://get.docker.com | sh
    sudo systemctl start docker
    sudo systemctl enable docker
fi

if ! command -v 7z &>/dev/null; then
    warn "$(get_string "restore_7z_not_found")"
    sudo apt-get install -y p7zip-full
fi

if [ ! -d "$REMWAVE_DIR" ]; then
    info "$(get_string "restore_creating_directory" "$REMWAVE_DIR")"
    mkdir -p "$REMWAVE_DIR"
fi

info "$(get_string "restore_checking_archive")"
TMP_RESTORE_DIR="$WORK_DIR/unpack"
mkdir -p "$TMP_RESTORE_DIR"
7z x -p"$PASSWORD" "$ARCHIVE_PATH" -o"$TMP_RESTORE_DIR" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    error "$(get_string "restore_invalid_password")"
    read -n 1 -s -r -p "$(get_string "restore_press_key")"; exit 1
fi

info "$(get_string "restore_backup_before")"
RESERVE_ARCHIVE="remnawave-backup-before-restore-$DATE.7z"

if [ -f "$REMWAVE_DIR/.env" ] && [ -f "$REMWAVE_DIR/docker-compose.yml" ]; then
    cp "$REMWAVE_DIR/.env" "$BACKUP_DIR/"
    cp "$REMWAVE_DIR/docker-compose.yml" "$BACKUP_DIR/"
fi

if docker volume inspect $DB_VOLUME &>/dev/null; then
    docker run --rm \
        -v ${DB_VOLUME}:/volume \
        -v "$BACKUP_DIR":/backup \
        alpine \
        tar czf /backup/db_backup.tar.gz -C /volume .
fi

7z a -t7z -m0=lzma2 -mx=9 -mfb=273 -md=64m -ms=on -p"$PASSWORD" "$BACKUP_DIR/$RESERVE_ARCHIVE" "$BACKUP_DIR/db_backup.tar.gz" "$BACKUP_DIR/.env" "$BACKUP_DIR/docker-compose.yml" >/dev/null 2>&1
rm -f "$BACKUP_DIR/db_backup.tar.gz" "$BACKUP_DIR/.env" "$BACKUP_DIR/docker-compose.yml"

if [ "$SOURCE" = "telegram" ]; then
    curl -F "chat_id=$CHAT_ID" \
         -F document=@"$BACKUP_DIR/$RESERVE_ARCHIVE" \
         "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" >/dev/null 2>&1
fi

success "$(get_string "restore_backup_saved" "$BACKUP_DIR/$RESERVE_ARCHIVE")"

if [ -d "$REMWAVE_DIR" ]; then
    info "$(get_string "restore_stopping_containers")"
    cd "$REMWAVE_DIR" && docker compose down
    
    info "$(get_string "restore_removing_old_data")"
    docker volume rm $DB_VOLUME $REDIS_VOLUME 2>/dev/null || true
    rm -f "$REMWAVE_DIR/.env" "$REMWAVE_DIR/docker-compose.yml"
fi

info "$(get_string "restore_restoring_configs")"

ENV_FILE=$(find "$TMP_RESTORE_DIR" -name ".env" -type f 2>/dev/null | head -n1)
COMPOSE_FILE=$(find "$TMP_RESTORE_DIR" -name "docker-compose.yml" -type f 2>/dev/null | head -n1)
DB_BACKUP_FILE=$(find "$TMP_RESTORE_DIR" -name "remnawave-db-backup-*.tar.gz" -type f 2>/dev/null | head -n1)

if [ -z "$ENV_FILE" ] || [ -z "$COMPOSE_FILE" ]; then
    error "$(get_string "restore_configs_not_found")"
    rm -rf "$WORK_DIR"
    read -n 1 -s -r -p "$(get_string "restore_press_key")"; exit 1
fi

if [ -z "$DB_BACKUP_FILE" ]; then
    error "$(get_string "restore_db_backup_not_found")"
    rm -rf "$WORK_DIR"
    read -n 1 -s -r -p "$(get_string "restore_press_key")"; exit 1
fi

cp "$ENV_FILE" "$REMWAVE_DIR/"
cp "$COMPOSE_FILE" "$REMWAVE_DIR/"

DB_BACKUP_DIR=$(dirname "$DB_BACKUP_FILE")
DB_BACKUP_NAME=$(basename "$DB_BACKUP_FILE")

info "$(get_string "restore_starting_containers")"
cd "$REMWAVE_DIR" && docker compose up -d
sleep 10

info "$(get_string "restore_stopping_containers_again")"
docker compose down

info "$(get_string "restore_clearing_database")"
docker run --rm \
    -v ${DB_VOLUME}:/volume \
    alpine \
    sh -c "rm -rf /volume/*"

info "$(get_string "restore_restoring_database")"
docker run --rm \
    -v ${DB_VOLUME}:/volume \
    -v "$DB_BACKUP_DIR":/backup \
    alpine \
    tar xzf /backup/$DB_BACKUP_NAME -C /volume

info "$(get_string "restore_removing_temp")"
rm -rf "$WORK_DIR"

info "$(get_string "restore_starting_remnawave")"
cd "$REMWAVE_DIR" && docker compose up -d

success "$(get_string "restore_complete")"
read -n 1 -s -r -p "$(get_string "restore_press_key")"
exit 0 