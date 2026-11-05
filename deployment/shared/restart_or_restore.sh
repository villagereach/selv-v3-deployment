#!/usr/bin/env bash

if [ "$KEEP_OR_WIPE" == "wipe" ]; then
    export $(grep -v '^#' settings.env | grep -v '.*=.* .*' | grep -v '.*\..*=' | xargs)
    
    cp ../../credentials/${CREDENTIALS_SUB_DIRECTORY}/.env-restore ./.env-restore

    echo "Restoring database from the latest backup"
    LATEST_BACKUP_NAME=`aws s3 ls $BUCKET_NAME --recursive | awk '$4 ~ /\.sql\.zip$/' | sort | tail -n 1 | awk '{print $4}'`

    echo "LATEST BACKUP FILE FROM S3 - $LATEST_BACKUP_NAME"
    if [ -z "$LATEST_BACKUP_NAME" ]; then
        echo "No backup found in $BUCKET_NAME" >&2
        exit 1
    fi
    # Keys may carry a prefix (daily/, manual/, ...), so download to the fixed name directly
    if ! aws s3 cp "s3://$BUCKET_NAME/$LATEST_BACKUP_NAME" backup_file.sql.zip; then
        echo "Download of $LATEST_BACKUP_NAME failed" >&2
        rm -f backup_file.sql.zip
        exit 1
    fi

    ../shared/restore.sh
    ../shared/after_restore.sh
    rm -f ./.env-restore
else
    ../shared/restart.sh $1
fi
