#!/usr/bin/env bash

export DOCKER_TLS_VERIFY="1"
export COMPOSE_TLS_VERSION=TLSv1_2
export DOCKER_HOST="reporting.test.selv.org.mz:2376"
export DOCKER_CERT_PATH="${PWD}/../../../credentials/test_reporting_env"
export DOCKER_COMPOSE_BIN=/usr/local/bin/docker-compose

export REPORTING_DIR_NAME=reporting

distro_repo=$1

docker volume create pgdata

cd "$distro_repo/$REPORTING_DIR_NAME" &&
$DOCKER_COMPOSE_BIN kill &&
$DOCKER_COMPOSE_BIN down -v --remove-orphans &&

/usr/local/bin/docker-compose build &&

$DOCKER_COMPOSE_BIN up -d --scale scalyr=0
