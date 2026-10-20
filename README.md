# OpenLMIS SELV V3 deployment
Location for the OpenLMIS v3+ SELV deployment scripts and resources

## Database Config

#### Volume initialization
To fully support all required features, the PostgreSQL database has to be adjusted.
All necessary config files are available in `deployment/shared/pgdata` directory. Due to 
lack of required permissions to access the volume directly while being outside of the server,
the files has to be moved to a temporary location at first:
1. Move the files to the temporary directory on the server:
```$shell
scp -r deployment/shared/config/pgdata <user>@<put target server address here>:/tmp
```
5. Enter the server via SSH
6. Switch to superuser in order to gain required permissions to modify the db volume (`sudo su`)
7. Move all necessary files to the volume: 
```$shell
cp -rf /tmp/pgdata /var/lib/docker/volumes && rm /tmp/pgdata -r
```

#### Auth Server credentials
If the database has been wiped out, or not yet initiated it's possible that the initial credentials for the auth server 
are not configured and the UI can't connect to the server properly (and user receives HTTP code 401
when trying to log in). In order to fix that, values for both server and UI client in
`auth.oath_clent_details` table should reflect the values from env file (`settings.env` or
`.env-restore`). `authorizedgranttypes` column helps to establish if the credentials are for the
server side (`client_credentials`) or for the UI side (`password`).

#### Rights added by hand (not by migrations)
Rights live in the referencedata service, so SELV extension modules cannot create the ones they
check. These have to be added once per environment after the deployment that introduces them,
then assigned to a role on the Administration > Roles screen:

| Right | Needed since | How to add |
|---|---|---|
| `EXCHANGE_RATE_MANAGE` (`GENERAL_ADMIN`) | selv-v3-fulfillment-extension 1.1.0 / selv-v3-ui after v1.2.0 (SELV3-845) | API call or SQL in the [selv-v3-fulfillment-extension README](https://github.com/villagereach/selv-v3-fulfillment-extension#required-manual-configuration) |

#### Postgres extensions
If for some reason extensions specified in [this file](https://github.com/OpenLMIS/postgres/blob/master/init/init-openlmis-db.sh)
were not created properly - it might result in errors while executing the initial SQL migrations. In this case,
the extensions should be created manually:
```
DROP EXTENSION IF EXISTS "uuid-ossp"; CREATE EXTENSION "uuid-ossp";
DROP EXTENSION IF EXISTS "postgis"; CREATE EXTENSION "postgis";
```
