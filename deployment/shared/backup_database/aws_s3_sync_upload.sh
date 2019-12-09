!/bin/bash

# load config
source backup_database/pg_backup.config

# upload bacups to aws S3
/home/ubuntu/.local/bin/aws s3 sync $BACKUP_DIR $S3_LOCATION --delete



