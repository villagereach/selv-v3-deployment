#!/bin/bash

# load config
source backup_database/pg_backup.config

# download files from aws S3
/home/ubuntu/.local/bin/aws s3 sync $S3_LOCATION $BACKUP_DIR --delete


