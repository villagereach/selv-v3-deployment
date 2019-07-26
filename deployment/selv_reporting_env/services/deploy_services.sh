#!/usr/bin/env bash

export DOCKER_TLS_VERIFY="1"
export COMPOSE_TLS_VERSION=TLSv1_2
export DOCKER_HOST="3.223.246.33:2376"
export DOCKER_CERT_PATH="${PWD}/../../../credentials/selv_reporting_env"
export DOCKER_COMPOSE_BIN=/usr/local/bin/docker-compose

export REPORTING_DIR_NAME=reporting

distro_repo=$1
init_with_lets_encrypt_sh_path="../../deployment/shared/init_with_lets_encrypt.sh"

# In order to avoid generated new certificates between next deploys of ReportingStack
# we need to move them to seperate volume marked as external.
# External volumes are not removed even we use docker-compose down with -v option.
# The external volume need to be created before the docker start
docker volume create letsencrypt-config

cd "$distro_repo/$REPORTING_DIR_NAME" &&
$DOCKER_COMPOSE_BIN kill &&
$DOCKER_COMPOSE_BIN down -v --remove-orphans &&

/usr/local/bin/docker-compose build &&
#. $init_with_lets_encrypt_sh_path &&

$DOCKER_COMPOSE_BIN up -d --scale scalyr=0
