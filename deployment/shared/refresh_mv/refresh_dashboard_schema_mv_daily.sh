#!/bin/bash

###########################
####### LOAD CONFIG #######
###########################

source /home/ubuntu/refresh_mv/refresh_mv.config

MATERIALIZED_VIEWS=(
  ${MV_FACILITIES}
  ${MV_CALCULATED_STOCKS_ON_HAND}
  ${MV_CCE_INVENTORY}
  ${MV_STOCKS_ON_HAND_BY_LOT}
  ${MV_STOCK_MOVEMENTS}
  ${MV_STOCK_ON_HAND_CONSUMPTION}
  ${MV_STOCK_OUT}
  ${MV_REQUISITION_STATUS}
  ${MV_REQUISITION_WITH_ITEMS}
  ${MV_REQUISITION_REPORT_RATE}
)

############################
#####  START REFRESH  ######
############################

echo "----------------------------------------------------" | tee -a "${LOG_FILE}"
echo "$(date): Starting refresh process" | tee -a "${LOG_FILE}"

function refresh_daily_materialized_views()
{
    container_id=$(sudo docker ps | grep ${POSTGRES_CONTAINER_NAME} | awk '{print $1}')

    for view in "${MATERIALIZED_VIEWS[@]}"; do
        echo "$(date): Starting refresh for materialized view: ${view}" | tee -a "${LOG_FILE}"
        sudo docker exec $container_id psql -U postgres -d ${DATABASE_NAME} -c "REFRESH MATERIALIZED VIEW ${view} WITH DATA" >> "${LOG_FILE}" 2>&1
        echo "$(date): Refresh completed for materialized view: ${view}" | tee -a "${LOG_FILE}"
    done
}

refresh_daily_materialized_views

echo "$(date): Refresh process completed" | tee -a "${LOG_FILE}"
exit 0;
