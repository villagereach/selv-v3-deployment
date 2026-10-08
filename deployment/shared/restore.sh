#!/bin/bash

export $(grep -v '^#' settings.env | grep -v '.*=.* .*' | grep -v '.*\..*=' | xargs)
set -e
set -o pipefail

if [ -f backup_file.sql.zip ]
then
    # ensure some environment variables are set
    : "${POSTGRES_CONTAINER_NAME:?POSTGRES_CONTAINER_NAME not set in environment}"
    : "${DATABASE_NAME:?DATABASE_NAME not set in environment}"

    FILE_COUNT=`unzip -l backup_file.sql.zip | tail -1 | awk '{printf $2}'`

    if [ "$FILE_COUNT" -gt 1 ]
    then
        echo "More than one file in zip"
        exit 1;
    fi

    # Verify the archive before anything on the server is touched
    unzip -tq backup_file.sql.zip

    echo "Docker host - $DOCKER_HOST"
    echo "POSTGRES_CONTAINER_NAME - $POSTGRES_CONTAINER_NAME"
    echo "DATABASE_NAME - $DATABASE_NAME"
    
    docker container stop $(docker container ls -aq)

    docker start ${POSTGRES_CONTAINER_NAME}

    # docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "SELECT pg_drop_replication_slot('debezium');"
    docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "DROP DATABASE ${DATABASE_NAME};"
    docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "CREATE DATABASE ${DATABASE_NAME};"

    # Stream the dump straight into Postgres, so the unzipped file never lands on disk
    unzip -p backup_file.sql.zip | docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -d ${DATABASE_NAME}

    rm -f backup_file.sql.zip
    ../shared/restart.sh
else
    echo "Missing reference backup zip file"
    exit 1
fi


