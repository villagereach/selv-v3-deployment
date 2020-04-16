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

#### Postgres extensions
If for some reason extensions specified in [this file](https://github.com/OpenLMIS/postgres/blob/master/init/init-openlmis-db.sh)
were not created properly - it might result in errors while executing the initial SQL migrations. In this case,
the extensions should be created manually:
```
DROP EXTENSION IF EXISTS "uuid-ossp"; CREATE EXTENSION "uuid-ossp";
DROP EXTENSION IF EXISTS "postgis"; CREATE EXTENSION "postgis";
```
