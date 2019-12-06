#!/usr/bin/env bash

if [ "$KEEP_OR_WIPE" == "wipe" ]; then
    export $(grep -v '^#' settings.env | xargs)
    
    echo "Restoring database from the latest backup"
    LATEST_BACKUP_NAME=`aws s3 ls $BUCKET_NAME --recursive | sort | tail -n 1 | awk '{print $4}'`

    echo "LATEST BACKUP FILE FROM S3 - $LATEST_BACKUP_NAME"
    aws s3 cp s3://$BUCKET_NAME/$LATEST_BACKUP_NAME .
    mv $LATEST_BACKUP_NAME backup_file.sql.zip

    ../shared/restore.sh
    ../shared/after_restore.sh
else
    ../shared/restart.sh $1
fi
