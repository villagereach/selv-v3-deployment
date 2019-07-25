#!/usr/bin/env bash

# This file should be replaced by ../shared/restart_or_restore.sh and ../shared/restart.sh when the deploy
# workflow will be tested on dev instance. Also ../shared/restart_or_restore.sh and ../shared/restart.sh should be
# modified in order to use init_with_lets_encrypt.sh.

if [ "$KEEP_OR_WIPE" == "wipe" ]; then
    echo "Restoring database from the latest snapshot"
    cp ../../credentials/${CREDENTIALS_SUB_DIRECTORY}/.env-restore ../shared/restore/.env-restore

    /usr/local/bin/docker-compose down -v --remove-orphans
    /usr/local/bin/docker-compose build
    ../shared/init_with_lets_encrypt.sh
    /usr/local/bin/docker-compose -f ../shared/restore/docker-compose.yml run rds-restore
    /usr/local/bin/docker-compose up -d

    rm -f ../shared/restore/.env-restore
else
    KEEP_MSG="Will keep data."

    /usr/local/bin/docker-compose down
    echo "$KEEP_MSG";
    export spring_profiles_active="production"
    /usr/local/bin/docker-compose build
    ../shared/init_with_lets_encrypt.sh
    /usr/local/bin/docker-compose up -d
fi
