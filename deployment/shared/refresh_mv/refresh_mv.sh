#!/bin/bash

###########################
####### LOAD CONFIG #######
###########################

source /home/ubuntu/refresh_mv/refresh_mv.config

MATERIALIZED_VIEWS=(
  ${MV_CALCULATED_STOCK_ON_HAND}
  ${MV_COVAX_PHYSICAL_INVENTORIES_REPORTS}
  ${MV_PAV_INVENTORY_LINE_ITEMS}
  ${MV_STOCK_CARD_LINE_ITEMS}
  ${MV_STOCK_PHYS_INV}
  ${MV_STOCK_PHYS_INV_LINE_ITEMS}
)

############################
#####  START REFRESH  ######
############################

function refresh_materialized_views()
{
    container_id=$(sudo docker ps | grep ${POSTGRES_CONTAINER_NAME} | awk '{print $1}')

    # Refresh materialized views
    for view in "${MATERIALIZED_VIEWS[@]}"; do
        echo "Starting refresh for materialized view: ${view}"
        sudo docker exec $container_id psql -U postgres -d ${DATABASE_NAME} -c "REFRESH MATERIALIZED VIEW ${view}"
        echo "Refresh completed for materialized view: ${view}"
    done
}

refresh_materialized_views
exit 0;
