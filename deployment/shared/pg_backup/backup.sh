#!/bin/bash

date=$(date +%Y-%m-%d"_"%H_%M_%S)
backup_filename="${DATABASE_NAME}_${date}.sql"
backup_filename_zipped="${backup_filename}.gz"
s3_location=${S3_LOCATION}

container_id=$(docker ps | grep ${POSTGRES_CONTAINER_NAME} | awk '{print $1}')

# create the backup
echo "Starting backup for database ${DATABASE_NAME}..."
docker exec $container_id pg_dump -U postgres -f /var/backups/$backup_filename ${DATABASE_NAME}

# copy file inside container to host
docker cp $container_id:/var/backups/$backup_filename .

# remove file in container
docker exec $container_id rm /var/backups/$backup_filename

# compress
gzip $backup_filename

# upload to s3
echo "Sending backup file $backup_filename_zipped to $s3_location"
aws s3 cp $backup_filename_zipped $s3_location
echo "Backup file successfully sent to S3"

rm $backup_filename_zipped

echo "Database backup complete!"