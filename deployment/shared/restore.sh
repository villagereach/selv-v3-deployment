#!/bin/bash

export $(grep -v '^#' settings.env | grep -v '.*=.* .*' | grep -v '.*\..*=' | xargs)
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

    # Load the dump on the database host: streaming 25 GB over docker exec from Jenkins gets cut off
    docker cp backup_file.sql.zip ${POSTGRES_CONTAINER_NAME}:/tmp/backup_file.sql.zip
    rm -f backup_file.sql.zip

    echo "Docker host - $DOCKER_HOST"
    echo "POSTGRES_CONTAINER_NAME - $POSTGRES_CONTAINER_NAME"
    echo "DATABASE_NAME - $DATABASE_NAME"
    
    docker container stop $(docker container ls -aq)

    docker start ${POSTGRES_CONTAINER_NAME}

    # docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "SELECT pg_drop_replication_slot('debezium');"
    docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "DROP DATABASE ${DATABASE_NAME};"
    docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "CREATE DATABASE ${DATABASE_NAME};"

    docker exec ${POSTGRES_CONTAINER_NAME} bash -o pipefail -c "python3 -c 'import shutil, sys, zipfile; z = zipfile.ZipFile(sys.argv[1]); shutil.copyfileobj(z.open(z.namelist()[0]), sys.stdout.buffer, 1 << 24)' /tmp/backup_file.sql.zip | psql -U postgres -d ${DATABASE_NAME}"
    docker exec ${POSTGRES_CONTAINER_NAME} rm -f /tmp/backup_file.sql.zip
    ../shared/restart.sh
else
    echo "Missing reference backup zip file"
fi


