#!/usr/bin/env bash

export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="www.selv.org.mz:2376"
export DOCKER_CERT_PATH="${PWD}/../../credentials/production_env"

/usr/local/bin/docker-compose pull

../shared/restore.sh