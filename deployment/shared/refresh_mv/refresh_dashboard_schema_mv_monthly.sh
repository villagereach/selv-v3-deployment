#!/bin/bash

###########################
####### LOAD CONFIG #######
###########################

source /home/ubuntu/refresh_mv/refresh_mv.config

MATERIALIZED_VIEWS=(
  ${MV_STOCKOUTS}
)

############################
#####  START REFRESH  ######
############################

echo "----------------------------------------------------" | tee -a "${LOG_FILE}"
echo "$(date): Starting refresh process" | tee -a "${LOG_FILE}"

function refresh_monthly_materialized_views()
{
    container_id=$(sudo docker ps | grep ${POSTGRES_CONTAINER_NAME} | awk '{print $1}')

    for view in "${MATERIALIZED_VIEWS[@]}"; do
        echo "$(date): Starting refresh for materialized view: ${view}" | tee -a "${LOG_FILE}"
        sudo docker exec $container_id psql -U postgres -d ${DATABASE_NAME} -c "REFRESH MATERIALIZED VIEW ${view} WITH DATA" >> "${LOG_FILE}" 2>&1
        echo "$(date): Refresh completed for materialized view: ${view}" | tee -a "${LOG_FILE}"
    done
}

refresh_monthly_materialized_views

echo "$(date): Refresh process completed" | tee -a "${LOG_FILE}"
exit 0;
