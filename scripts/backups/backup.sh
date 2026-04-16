#!/bin/bash

source "/opt/remnasetup/scripts/common/colors.sh"
source "/opt/remnasetup/scripts/common/functions.sh"
source "/opt/remnasetup/scripts/common/languages.sh"

BACKUP_DIR="/opt/backups"
DATE=$(date +%F_%H-%M-%S)
DB_VOLUME="remnawave-db-data"
REMWAVE_DIR="/opt/remnawave"

DB_TAR="remnawave-db-backup-$DATE.tar.gz"
FINAL_ARCHIVE="remnawave-backup-$DATE.7z"
TMP_DIR="$BACKUP_DIR/tmp-$DATE"

mkdir -p "$BACKUP_DIR"

while true; do
    question "$(get_string "backup_enter_password")"
    ARCHIVE_PASSWORD="$REPLY"
    if [ ${#ARCHIVE_PASSWORD} -ge 8 ]; then
        break
    else
        warn "$(get_string "backup_password_short")"
    fi
done

echo

for cmd in docker tar 7z; do
    if ! command -v $cmd &>/dev/null; then
        warn "$(get_string "backup_cmd_not_found" "$cmd")"
        if command -v apt-get &>/dev/null; then
            sudo apt-get update
            if [ "$cmd" = "7z" ]; then
                sudo apt-get install -y p7zip-full
            else
                sudo apt-get install -y $cmd
            fi
        elif command -v yum &>/dev/null; then
            sudo yum install -y $cmd
        elif command -v apk &>/dev/null; then
            sudo apk add $cmd
        else
            error "$(get_string "backup_install_failed" "$cmd")"
            read -n 1 -s -r -p "$(get_string "backup_press_key")"; exit 1
        fi
        if ! command -v $cmd &>/dev/null; then
            error "$(get_string "backup_cmd_not_installed" "$cmd")"
            read -n 1 -s -r -p "$(get_string "backup_press_key")"; exit 1
        fi
    fi
done

if ! docker volume inspect $DB_VOLUME &>/dev/null; then
    error "$(get_string "backup_volume_not_found" "$DB_VOLUME")"
    read -n 1 -s -r -p "$(get_string "backup_press_key")"; exit 1
fi

if [ ! -d "$REMWAVE_DIR" ]; then
    error "$(get_string "backup_dir_not_found" "$REMWAVE_DIR")"
    read -n 1 -s -r -p "$(get_string "backup_press_key")"; exit 1
fi

if [ ! -f "$REMWAVE_DIR/.env" ]; then
    error "$(get_string "backup_env_not_found" "$REMWAVE_DIR")"
    read -n 1 -s -r -p "$(get_string "backup_press_key")"; exit 1
fi

if [ ! -f "$REMWAVE_DIR/docker-compose.yml" ]; then
    error "$(get_string "backup_compose_not_found" "$REMWAVE_DIR")"
    read -n 1 -s -r -p "$(get_string "backup_press_key")"; exit 1
fi

mkdir -p "$TMP_DIR"

info "$(get_string "backup_volume" "$DB_VOLUME")"
docker run --rm \
    -v ${DB_VOLUME}:/volume \
    -v "$TMP_DIR":/backup \
    alpine \
    tar czf /backup/$DB_TAR -C /volume .

info "$(get_string "backup_copying_configs")"
cp "$REMWAVE_DIR/.env" "$TMP_DIR/"
cp "$REMWAVE_DIR/docker-compose.yml" "$TMP_DIR/"

info "$(get_string "backup_creating_archive")"
(cd "$TMP_DIR" && 7z a -t7z -m0=lzma2 -mx=9 -mfb=273 -md=64m -ms=on -p"$ARCHIVE_PASSWORD" "$BACKUP_DIR/$FINAL_ARCHIVE" . >/dev/null 2>&1)
if [ $? -ne 0 ]; then
    error "$(get_string "backup_archive_error")"
    ls -l "$TMP_DIR"
    rm -rf "$TMP_DIR"
    exit 1
fi

rm -rf "$TMP_DIR"

success "$(get_string "backup_ready" "$BACKUP_DIR/$FINAL_ARCHIVE")"

S3_CONFIG="$BACKUP_DIR/auto_backup/backup.sh"
if [ -f "$S3_CONFIG" ] && grep -q 'S3_ENDPOINT=' "$S3_CONFIG" 2>/dev/null; then
    S3_ENDPOINT=$(grep '^S3_ENDPOINT=' "$S3_CONFIG" | head -1 | cut -d'"' -f2)
    if [ -n "$S3_ENDPOINT" ]; then
        while true; do
            question "$(get_string "backup_upload_s3")"
            if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
                S3_ACCESS_KEY=$(grep '^S3_ACCESS_KEY=' "$S3_CONFIG" | head -1 | cut -d'"' -f2)
                S3_SECRET_KEY=$(grep '^S3_SECRET_KEY=' "$S3_CONFIG" | head -1 | cut -d'"' -f2)
                S3_BUCKET=$(grep '^S3_BUCKET=' "$S3_CONFIG" | head -1 | cut -d'"' -f2)
                S3_REGION=$(grep '^S3_REGION=' "$S3_CONFIG" | head -1 | cut -d'"' -f2)
                S3_PATH=$(grep '^S3_PATH=' "$S3_CONFIG" | head -1 | cut -d'"' -f2)

                export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
                export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"

                S3_PREFIX="${S3_PATH%/}"
                S3_OBJECT_KEY="${S3_PREFIX}/${FINAL_ARCHIVE}"

                info "$(get_string "backup_s3_uploading")"
                if aws s3 cp "$BACKUP_DIR/$FINAL_ARCHIVE" "s3://${S3_BUCKET}/${S3_OBJECT_KEY}" \
                    --endpoint-url "$S3_ENDPOINT" \
                    --region "${S3_REGION:-us-east-1}" \
                    --quiet; then
                    success "$(get_string "backup_s3_uploaded" "$S3_OBJECT_KEY")"
                else
                    error "$(get_string "backup_s3_upload_failed")"
                fi
                break
            elif [[ "$REPLY" == "n" || "$REPLY" == "N" ]]; then
                break
            fi
        done
    fi
fi

read -n 1 -s -r -p "$(get_string "backup_press_key")"
exit 0