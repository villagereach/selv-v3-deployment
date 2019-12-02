#!/usr/bin/env bash

if [ -f backup_file.sql.zip ]
then
    unzip -o backup_file.sql.zip
    sudo docker-compose down

    sudo docker start dev_env_db_1

    sudo docker exec -i dev_env_db_1 psql -U postgres -c 'DROP DATABASE open_lmis;'
    sudo docker exec -i dev_env_db_1 psql -U postgres -c 'CREATE DATABASE open_lmis;'

    cat backup_file.sql | sudo docker exec -i dev_env_db_1 psql -U postgres -d open_lmis

    export spring_profiles_active="production"
    sudo docker-compose up --build --force-recreate -d
else
    echo "Missing reference backup zip file"
fi


