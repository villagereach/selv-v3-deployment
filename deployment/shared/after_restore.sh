#!/bin/bash

export $(grep -v '^#' .env-restore | xargs)

: ${POSTGRES_USER:?"Need to set POSTGRES_USER"}
: ${POSTGRES_CONTAINER_NAME:?"POSTGRES_CONTAINER_NAME not set in environment"}
: ${DATABASE_NAME:?"DATABASE_NAME not set in environment"}
: ${ENCODED_USER_PASSWORD:?"Need to set ENCODED_USER_PASSWORD"}
: ${SERVICE_CLIENT_ID:?"Need to set SERVICE_CLIENT_ID"}
: ${SERVICE_CLIENT_SECRET:?"Need to set SERVICE_CLIENT_SECRET"}
: ${CLIENT_SECRET:?"Need to set CLIENT_SECRET"}
: ${CLIENT_USERNAME:?"Need to set CLIENT_USERNAME"}
: ${SUPERSET_CLIENT:?"Need to set SUPERSET_CLIENT"}
: ${SUPERSET_CLIENT_REDIRECT_URI:?"Need to set SUPERSET_CLIENT_REDIRECT_URI"}

sql="UPDATE auth.auth_users SET password = '${ENCODED_USER_PASSWORD}';
UPDATE notification.user_contact_details SET email = NULL, phonenumber = NULL, allownotify = false;
UPDATE auth.oauth_client_details SET clientsecret = '${SERVICE_CLIENT_SECRET}' WHERE clientid = '${SERVICE_CLIENT_ID}';
UPDATE auth.oauth_client_details SET clientsecret = '${CLIENT_SECRET}' WHERE clientid = '${CLIENT_USERNAME}';
UPDATE auth.oauth_client_details SET redirecturi = '${SUPERSET_CLIENT_REDIRECT_URI}' WHERE clientid = '${SUPERSET_CLIENT}';"

docker exec -i $POSTGRES_CONTAINER_NAME psql -U $POSTGRES_USER -d $DATABASE_NAME -c "$sql"

# The read-only role postgres_exporter logs in as (monitoring/alloy/README.md).
# A restore keeps cluster roles (it drops and recreates only the database), but
# a wiped pgdata volume loses them; re-create it when MONITORING_DB_PASSWORD is set.
if [ -n "${MONITORING_DB_PASSWORD:-}" ]; then
  docker exec -i $POSTGRES_CONTAINER_NAME psql -v ON_ERROR_STOP=1 -U $POSTGRES_USER -d $DATABASE_NAME -v pw="${MONITORING_DB_PASSWORD}" <<'SQL'
SELECT format('CREATE ROLE olmis_monitoring LOGIN PASSWORD %L', :'pw')
  WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'olmis_monitoring') \gexec
SELECT format('ALTER ROLE olmis_monitoring PASSWORD %L', :'pw') \gexec
GRANT pg_monitor TO olmis_monitoring;
SQL
  echo "Monitoring role ready."
fi
