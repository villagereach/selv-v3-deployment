#!/usr/bin/env bash

export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="test.selv.org.mz:2376"
export CREDENTIALS_SUB_DIRECTORY="test_env"
export DOCKER_CERT_PATH="${PWD}/../../credentials/${CREDENTIALS_SUB_DIRECTORY}"

/usr/local/bin/docker-compose pull

chmod 755 ./restore.sh
chmod 755 ../shared/restore.sh
../shared/restore.sh