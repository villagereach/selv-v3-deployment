## **Refreshing materialized views in the SELV-V3**

This folder (refresh_mv) reflects the structure of the files that are on the production and test instances in `/home/ubuntu/refresh_mv` for refreshing materialized views. The folder contains:

**- file refresh_mv.config:** view names and settings used in the other scripts. Set `POSTGRES_CONTAINER_NAME` to the database container of the server (`production_env_db_1` or `test_env_db_1`).

**- file refresh_mv.sh:** refreshes the stockmanagement schema views.

**- file refresh_physical_inventory_dashboards_daily.sh:** refreshes the physical inventory dashboard views.

**- file refresh_dashboard_schema_mv_daily.sh:** refreshes the daily dashboard views.

**- file refresh_dashboard_schema_mv_monthly.sh:** refreshes the monthly dashboard views.

All scripts except refresh_mv.sh write to `refresh_log.txt`, set in `LOG_FILE`.

**CRON**

Above scripts are run using cron on the `ubuntu` user (times in UTC):

```
0 23 * * * ./refresh_mv/refresh_mv.sh
30 23 18-28 * * ./refresh_mv/refresh_physical_inventory_dashboards_daily.sh
35 23 * * * ./refresh_mv/refresh_dashboard_schema_mv_daily.sh
30 0 1 * * ./refresh_mv/refresh_dashboard_schema_mv_monthly.sh
```

Use `crontab -e` command to edit cron tasks.
