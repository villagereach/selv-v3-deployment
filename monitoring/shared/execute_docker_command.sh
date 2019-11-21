#!/bin/bash
COMMAND=$1
HOST=$2

source ../$HOST/set_docker_variables.sh

echo "Executing docker command '$COMMAND' on the instance: $HOST" 

$COMMAND