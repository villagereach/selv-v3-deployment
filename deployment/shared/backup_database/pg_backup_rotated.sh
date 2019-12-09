#!/bin/bash

###########################
####### LOAD CONFIG #######
###########################

source backup_database/pg_backup.config

###########################
#### START THE BACKUPS ####
###########################

function perform_backups()
{
    SUFFIX=$1
    date=$(date +%Y-%m-%d)
    backup_filename="${DATABASE_NAME}_${date}$SUFFIX.sql"
    backup_filename_zipped="${backup_filename}.zip"
    s3_location=${S3_LOCATION}

    container_id=$(sudo docker ps | grep ${POSTGRES_CONTAINER_NAME} | awk '{print $1}')

    # create the backup
    echo "Starting backup for database ${DATABASE_NAME}..."
    sudo docker exec $container_id pg_dump -U postgres -f /var/backups/$backup_filename ${DATABASE_NAME}

    # copy file inside container to host
    sudo docker cp $container_id:/var/backups/$backup_filename .

    # remove file in container
    sudo docker exec $container_id rm /var/backups/$backup_filename

    # compress
    zip -m $backup_filename_zipped $backup_filename

    # move to directory with backups from S3
    mv $backup_filename_zipped $BACKUP_DIR

    echo "Database backup complete!"
}

# MONTHLY BACKUPS
DAY_OF_MONTH=`date +%d`

if [ $DAY_OF_MONTH -eq $DAY_OF_MONTHLY_BACKUP ];
then
        #find $BACKUP_DIR -maxdepth 1 -mtime +$EXPIRED_DAYS_MONTHLY -name '*-monthly.sql.zip' -exec rm -rf '{}' ';'      

        perform_backups "-monthly"
        exit 0;
fi

# WEEKLY BACKUPS
DAY_OF_WEEK=`date +%u` #1-7 (Monday-Sunday)

if [ $DAY_OF_WEEK = $DAY_OF_WEEKLY_BACKUP ];
then
    find $BACKUP_DIR -maxdepth 1 -mtime +$EXPIRED_DAYS_WEEKLY -name '*-weekly.sql.zip' -exec rm -rf '{}' ';'             
        perform_backups "-weekly"
        exit 0;
fi

# DAILY BACKUPS
find $BACKUP_DIR -maxdepth 1 -mtime +$EXPIRED_DAYS_DAILY -name '*-daily.sql.zip' -exec rm -rf '{}' ';'
perform_backups "-daily"

