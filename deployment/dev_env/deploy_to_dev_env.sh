#!/usr/bin/env bash

export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="dev.selv.org.mz:2376"
export CREDENTIALS_SUB_DIRECTORY="dev_env"
export DOCKER_CERT_PATH="${PWD}/../../credentials/${CREDENTIALS_SUB_DIRECTORY}"

/usr/local/bin/docker-compose pull

../shared/restart_or_restore.sh $1

sudo cp config/pgdata /var/lib/docker/volumes/ -rf
