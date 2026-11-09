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
        echo "More than one file in zip" >&2
        exit 1
    fi

    # Load the dump on the database host: streaming 25 GB over docker exec from Jenkins gets cut off
    docker cp backup_file.sql.zip ${POSTGRES_CONTAINER_NAME}:/tmp/backup_file.sql.zip
    rm -f backup_file.sql.zip

    echo "Docker host - $DOCKER_HOST"
    echo "POSTGRES_CONTAINER_NAME - $POSTGRES_CONTAINER_NAME"
    echo "DATABASE_NAME - $DATABASE_NAME"

    load_log=$(mktemp)
    # From here on the services are stopped and the database is replaced, so a failure leaves the
    # environment down. Restarting it on an empty database would only hide that.
    on_exit() {
        local rc=$?
        rm -f "$load_log"
        [ "$rc" -eq 0 ] || echo "Restore failed: the services on $DOCKER_HOST stay down until the next successful wipe" >&2
    }
    trap on_exit EXIT

    docker container stop $(docker container ls -aq)

    docker start ${POSTGRES_CONTAINER_NAME}

    # docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "SELECT pg_drop_replication_slot('debezium');"
    docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "DROP DATABASE ${DATABASE_NAME};"
    docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U postgres -c "CREATE DATABASE ${DATABASE_NAME};"

    docker exec ${POSTGRES_CONTAINER_NAME} bash -o pipefail -c "python3 -c 'import shutil, sys, zipfile; z = zipfile.ZipFile(sys.argv[1]); shutil.copyfileobj(z.open(z.namelist()[0]), sys.stdout.buffer, 1 << 24)' /tmp/backup_file.sql.zip | psql -U postgres -d ${DATABASE_NAME}" 2>&1 | tee "$load_log"
    load_status=${PIPESTATUS[0]}
    docker exec ${POSTGRES_CONTAINER_NAME} rm -f /tmp/backup_file.sql.zip
    if [ "$load_status" -ne 0 ]
    then
        echo "Database load failed with exit code $load_status" >&2
        exit 1
    fi

    # psql carries on past a failed statement. The production dump grants rights to roles that only
    # production has, and those grants are expected to fail here; any other error fails the restore.
    missing_role='ERROR:  role ".*" does not exist$'
    load_errors=$(grep -E '^ERROR:|^psql:[^ ]+ ERROR:' "$load_log" | grep -vE "$missing_role" || true)
    if [ -n "$load_errors" ]
    then
        echo "Database load reported errors:" >&2
        echo "$load_errors" >&2
        exit 1
    fi
    echo "Database load finished; $(grep -cE "$missing_role" "$load_log" || true) grants to roles missing on this server skipped"

    ../shared/restart.sh
else
    echo "Missing reference backup zip file" >&2
    exit 1
fi


