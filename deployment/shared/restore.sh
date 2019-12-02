#!/usr/bin/env bash

if [ -f backup_file.sql.zip ]
then
    unzip -o backup_file.sql.zip
    sudo docker-compose down

    sudo docker start ${POSTGRES_CONTAINER_NAME}

    sudo docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c 'DROP DATABASE ${DATABASE_NAME};'
    sudo docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c 'CREATE DATABASE ${DATABASE_NAME};'

    cat backup_file.sql | sudo docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -d ${DATABASE_NAME}

    export spring_profiles_active="production"
    sudo docker-compose up --build --force-recreate -d
else
    echo "Missing reference backup zip file"
fi


