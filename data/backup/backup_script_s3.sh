#!/bin/bash

BACKUP_DIR="/opt/backups"
DATE=$(date +%F_%H-%M-%S)
DB_VOLUME="remnawave-db-data"
REMWAVE_DIR="/opt/remnawave"
DB_TAR="remnawave-db-backup-$DATE.tar.gz"
FINAL_ARCHIVE="remnawave-backup-$DATE.7z"
TMP_DIR="$BACKUP_DIR/tmp-$DATE"

PASSWORD=""
LANGUAGE=""

S3_ENDPOINT=""
S3_ACCESS_KEY=""
S3_SECRET_KEY=""
S3_BUCKET=""
S3_REGION=""
S3_PATH=""
S3_KEEP=""

START_TIME=$(date +%s)

mkdir -p "$BACKUP_DIR"
mkdir -p "$TMP_DIR"

if docker volume inspect $DB_VOLUME &>/dev/null; then
  docker run --rm \
    -v ${DB_VOLUME}:/volume \
    -v "$TMP_DIR":/backup \
    alpine \
    tar czf /backup/$DB_TAR -C /volume .
fi

cp "$REMWAVE_DIR/.env" "$TMP_DIR/"
cp "$REMWAVE_DIR/docker-compose.yml" "$TMP_DIR/"

7z a -t7z -m0=lzma2 -mx=9 -mfb=273 -md=64m -ms=on -p"$PASSWORD" "$BACKUP_DIR/$FINAL_ARCHIVE" "$TMP_DIR/*" >/dev/null 2>&1

rm -rf "$TMP_DIR"

find "$BACKUP_DIR" -maxdepth 1 -type f -name 'remnawave-backup-*.7z' -mtime +3 -delete

END_TIME=$(date +%s)
DURATION_SEC=$((END_TIME - START_TIME))
DURATION=$(date -u -d @${DURATION_SEC} +%H:%M:%S)
ARCHIVE_SIZE=$(du -h "$BACKUP_DIR/$FINAL_ARCHIVE" | awk '{print $1}')

export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"

S3_PREFIX="${S3_PATH%/}"
S3_OBJECT_KEY="${S3_PREFIX}/${FINAL_ARCHIVE}"

if aws s3 cp "$BACKUP_DIR/$FINAL_ARCHIVE" "s3://${S3_BUCKET}/${S3_OBJECT_KEY}" \
    --endpoint-url "$S3_ENDPOINT" \
    --region "${S3_REGION:-us-east-1}" \
    --quiet; then
    if [ "$LANGUAGE" = "en" ]; then
        echo "[$(date)] S3 upload OK: ${S3_OBJECT_KEY} (${ARCHIVE_SIZE}, ${DURATION})"
    else
        echo "[$(date)] S3 загрузка OK: ${S3_OBJECT_KEY} (${ARCHIVE_SIZE}, ${DURATION})"
    fi
else
    if [ "$LANGUAGE" = "en" ]; then
        echo "[$(date)] S3 upload FAILED: ${S3_OBJECT_KEY}" >&2
    else
        echo "[$(date)] S3 загрузка ОШИБКА: ${S3_OBJECT_KEY}" >&2
    fi
    exit 1
fi

if [[ "$S3_KEEP" =~ ^[0-9]+$ ]] && [ "$S3_KEEP" -gt 0 ]; then
    OBJECTS=$(aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" \
        --endpoint-url "$S3_ENDPOINT" \
        --region "${S3_REGION:-us-east-1}" 2>/dev/null | sort | awk '{print $NF}')

    COUNT=$(echo "$OBJECTS" | wc -l)

    if [ "$COUNT" -gt "$S3_KEEP" ]; then
        DELETE_COUNT=$((COUNT - S3_KEEP))
        echo "$OBJECTS" | head -n "$DELETE_COUNT" | while read -r OBJ; do
            aws s3 rm "s3://${S3_BUCKET}/${S3_PREFIX}/${OBJ}" \
                --endpoint-url "$S3_ENDPOINT" \
                --region "${S3_REGION:-us-east-1}" \
                --quiet 2>/dev/null
        done
        if [ "$LANGUAGE" = "en" ]; then
            echo "[$(date)] S3 cleanup: deleted $DELETE_COUNT old backups"
        else
            echo "[$(date)] S3 очистка: удалено $DELETE_COUNT старых бекапов"
        fi
    fi
fi

exit 0
