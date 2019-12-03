#!/usr/bin/env bash

if [ -f backup_file.sql.zip ]
then
    FILE_COUNT = unzip -l backup_file.sql.zip | tail -1 | awk '{ print $2 }'
    
    if [ $FILE_COUNT > 1 ]
    then
        echo "More than one file in zip"
        exit 0;
    fi
    echo "Restore database - ${DATABASE_NAME}"
    echo "Container name - ${POSTGRES_CONTAINER_NAME}"
    unzip backup_file.sql.zip -d tmp_backup && mv tmp_backup/* "backup_file.sql"
    rm -d tmp_backup
    rm -f backup_file.sql.zip

    sudo docker stop $(sudo docker ps -a -q)

    sudo docker start $POSTGRES_CONTAINER_NAME

    sudo docker exec -i $POSTGRES_CONTAINER_NAME psql -U postgres -c "DROP DATABASE ${DATABASE_NAME};"
    sudo docker exec -i $POSTGRES_CONTAINER_NAME psql -U postgres -c "CREATE DATABASE ${DATABASE_NAME};"

    cat backup_file.sql | sudo docker exec -i $POSTGRES_CONTAINER_NAME psql -U postgres -d ${DATABASE_NAME}
    
    rm -f backup_file.sql
    ../shared/restart.sh
else
    echo "Missing reference backup zip file"
fi


