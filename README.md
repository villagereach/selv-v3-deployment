# OpenLMIS SELV V3 deployment
Location for the OpenLMIS v3+ SELV deployment scripts and resources

## DB Config
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
