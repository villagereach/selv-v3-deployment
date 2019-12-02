#!/usr/bin/env bash

if [ -f backup_file.zip ]
then
    unzip -o backup_file.zip
    /usr/local/bin/docker-compose down

    /usr/local/bin/docker start $POSTGRES_CONTAINER_NAME

    /usr/local/bin/docker exec -i $POSTGRES_CONTAINER_NAME psql -U postgres -c 'DROP DATABASE ${DATABASE_NAME};'
    /usr/local/bin/docker exec -i $POSTGRES_CONTAINER_NAME psql -U postgres -c 'CREATE DATABASE ${DATABASE_NAME};'

    cat backup_file.sql | /usr/local/bin/docker exec -i $POSTGRES_CONTAINER_NAME psql -U postgres -d $DATABASE_NAME

    export spring_profiles_active="production"
    /usr/local/bin/docker-compose up --build --force-recreate -d
else
    echo "Missing reference backup zip file"
fi


