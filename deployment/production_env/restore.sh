#!/usr/bin/env bash

export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="selv.org.mz:2376"
export DOCKER_CERT_PATH="${PWD}/../../credentials/production_env"

/usr/local/bin/docker-compose pull

chmod 755 ./restore.sh
chmod 755 ../shared/restore.sh
../shared/restore.sh