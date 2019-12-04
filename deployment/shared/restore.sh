#!/bin/bash

export $(grep -v '^#' settings.env | xargs)
set -e

if [ -f backup_file.sql.zip ]
then
    # ensure some environment variables are set
    : "${POSTGRES_CONTAINER_NAME:?POSTGRES_CONTAINER_NAME not set in environment}"
    : "${DATABASE_NAME:?DATABASE_NAME not set in environment}"

    FILE_COUNT=`unzip -l backup_file.sql.zip | tail -1 | awk '{printf $2}'`

    if [ "$FILE_COUNT" -gt 1 ]
    then
        echo "More than one file in zip"
        exit 0;
    fi

    unzip backup_file.sql.zip -d tmp_backup && mv tmp_backup/* "backup_file.sql"
    rm -d tmp_backup
    rm -f backup_file.sql.zip

    echo "Containers list: "
    docker container ls -aq
    echo "Docker host - $DOCKER_HOST"
    echo "POSTGRES_CONTAINER_NAME - $POSTGRES_CONTAINER_NAME"
    echo "DATABASE_NAME - $DATABASE_NAME"
    
    docker container stop $(docker container ls -aq)

    docker start ${POSTGRES_CONTAINER_NAME}

    docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "DROP DATABASE ${DATABASE_NAME};"
    docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "CREATE DATABASE ${DATABASE_NAME};"

    cat backup_file.sql | docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -d ${DATABASE_NAME}
    
    rm -f backup_file.sql
    ../shared/restart.sh
else
    echo "Missing reference backup zip file"
fi


