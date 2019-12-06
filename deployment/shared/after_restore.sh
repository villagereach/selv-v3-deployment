#!/bin/bash

export $(grep -v '^#' settings.env | xargs)

: ${POSTGRES_USER:?"Need to set POSTGRES_USER"}
: ${POSTGRES_CONTAINER_NAME:?"POSTGRES_CONTAINER_NAME not set in environment"}
: ${DATABASE_NAME:?"DATABASE_NAME not set in environment"}
: ${ENCODED_USER_PASSWORD:?"Need to set ENCODED_USER_PASSWORD"}
: ${auth.server.clientSecret:?"Need to set auth.server.clientSecret"}
: ${auth.server.clientId:?"Need to set auth.server.clientId"}
: ${AUTH_SERVER_CLIENT_SECRET:?"Need to set AUTH_SERVER_CLIENT_SECRET"}
: ${AUTH_SERVER_CLIENT_ID:?"Need to set AUTH_SERVER_CLIENT_ID"}

sql="UPDATE auth.auth_users SET password = '${ENCODED_USER_PASSWORD}';
UPDATE notification.user_contact_details SET email = NULL;
UPDATE auth.oauth_client_details SET clientsecret = '${auth.server.clientSecret}' WHERE clientid = '${auth.server.clientId}';
UPDATE auth.oauth_client_details SET clientsecret = '${AUTH_SERVER_CLIENT_SECRET}' WHERE clientid = '${AUTH_SERVER_CLIENT_ID}';"

docker exec -i $POSTGRES_CONTAINER_NAME psql -U $POSTGRES_USER -d $DATABASE_NAME -c "$sql"