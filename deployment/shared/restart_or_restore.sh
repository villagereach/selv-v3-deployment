#!/usr/bin/env bash

if [ "$KEEP_OR_WIPE" == "wipe" ]; then
    export $(grep -v '^#' settings.env | grep -v '.*=.* .*' | grep -v '.*\..*=' | xargs)
    
    cp ../../credentials/${CREDENTIALS_SUB_DIRECTORY}/.env-restore ./.env-restore

    echo "Restoring database from the latest backup"
    LATEST_BACKUP_NAME=`aws s3 ls $BUCKET_NAME --recursive | awk '$4 ~ /\.sql\.zip$/' | sort | tail -n 1 | awk '{print $4}'`

    echo "LATEST BACKUP FILE FROM S3 - $LATEST_BACKUP_NAME"
    if [ -z "$LATEST_BACKUP_NAME" ]; then
        echo "No backup found in $BUCKET_NAME" >&2
        rm -f ./.env-restore
        exit 1
    fi
    # Keys may carry a prefix (daily/, manual/, ...), so download to the fixed name directly
    if ! aws s3 cp "s3://$BUCKET_NAME/$LATEST_BACKUP_NAME" backup_file.sql.zip; then
        echo "Download of $LATEST_BACKUP_NAME failed" >&2
        rm -f backup_file.sql.zip ./.env-restore
        exit 1
    fi

    if ! ../shared/restore.sh; then
        echo "Database restore failed" >&2
        rm -f backup_file.sql.zip ./.env-restore
        exit 1
    fi
    # Before the services start, so they never run on production's users, contacts and secrets
    if ! ../shared/after_restore.sh; then
        echo "Post-restore steps failed: the services stay down until the next successful wipe" >&2
        rm -f ./.env-restore
        exit 1
    fi
    rm -f ./.env-restore
    if ! ../shared/restart.sh; then
        echo "Restart after the restore failed" >&2
        exit 1
    fi
else
    ../shared/restart.sh $1
fi
