#!/bin/bash

if [ -f backup_file.sql.zip ]
then
    DEFAULT_DATABASE_NAME='open_lmis'
    DEFAULT_POSTGRES_CONTAINER_NAME='dev_env_db_1'
    FILE_COUNT=`unzip -l backup_file.sql.zip | tail -1 | awk '{printf $2}'`

    if [ "$FILE_COUNT" -gt 1 ]
    then
        echo "More than one file in zip"
        exit 0;
    fi

    # if [ -n  "$DATABASE_NAME" ]
    # then
    #     echo "Setting the default value for database name - ${DATABASE_NAME}"
    #     DATABASE_NAME=$DEFAULT_DATABASE_NAME
    # fi

    # if [ -n  "$POSTGRES_CONTAINER_NAME" ]
    # then
    #     echo "Setting the default value for container name - ${POSTGRES_CONTAINER_NAME}"
    #     POSTGRES_CONTAINER_NAME=$DEFAULT_POSTGRES_CONTAINER_NAME
    # fi

    unzip backup_file.sql.zip -d tmp_backup && mv tmp_backup/* "backup_file.sql"
    rm -d tmp_backup
    rm -f backup_file.sql.zip

    echo "Containers list: "
    docker container ls -aq
    echo "Docker host - $DOCKER_HOST"
    docker container stop $(docker container ls -aq)

    docker start $POSTGRES_CONTAINER_NAME

    docker exec -i $POSTGRES_CONTAINER_NAME psql -U postgres -c "DROP DATABASE ${DATABASE_NAME};"
    docker exec -i $POSTGRES_CONTAINER_NAME psql -U postgres -c "CREATE DATABASE ${DATABASE_NAME};"

    cat backup_file.sql | docker exec -i $POSTGRES_CONTAINER_NAME psql -U postgres -d ${DATABASE_NAME}
    
    rm -f backup_file.sql
    ../shared/restart.sh
else
    echo "Missing reference backup zip file"
fi


