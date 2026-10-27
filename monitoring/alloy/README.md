# Grafana Alloy agent (SELV environments)

One Alloy agent per environment host. It collects host, container and app
metrics plus container logs and the nginx log files, and pushes them to the
central [soldevelo-monitoring](https://github.com/SolDevelo/soldevelo-monitoring)
stack at `olmis-monitoring.soldevelo.com`. Unrelated to the scripts in the
sibling `monitoring/<env>/` directories.

It runs as its own compose project (`soldevelo-monitoring-agents`), so app
deploys do not touch it.

## Files

| File | What |
|---|---|
| `config.alloy` | The package agent config, **vendored** at the tag in `PACKAGE_VERSION`. Never edit it here. |
| `selv.alloy` | SELV additions: nginx access/error logs from the `nginx-log` volume. |
| `sync-from-package.sh` | Re-copies `config.alloy` for `PACKAGE_VERSION`; `--check` reports drift. |
| `deploy_alloy.sh` | Builds the image on the env's Docker daemon and starts the agent. |
| `.env.example` | The variables. Real values: `<env>/alloy.env` in `selv-v3-configuration`. |

Upgrade: bump `PACKAGE_VERSION`, run `./sync-from-package.sh`, read the diff and
the package CHANGELOG, commit, deploy.

## Deploy

Jenkins job `SELV-monitoring-alloy-deploy-to-<env>`, manual. It checks out
this repo and `selv-v3-configuration` (into `credentials/`) and runs
`monitoring/alloy/deploy_alloy.sh <env>` from the workspace root, where `<env>`
(e.g. `test_env`) names the `selv-v3-configuration` directory holding
`alloy.env` and the Docker client certificates.

## Scraping apps

The agent scrapes containers labelled `monitoring.scrape: "true"`, at
`monitoring.port` + `monitoring.path`, named by `monitoring.service` (see
`deployment/test_env/docker-compose.yml`). Labels apply when the app containers
are recreated, i.e. on the next app deploy.

## PostgreSQL

`postgres-exporter` runs only with `COMPOSE_PROFILES=postgres` and
`PG_EXPORTER_DSN` in `<env>/alloy.env`. It logs in as a read-only role:

```sql
CREATE ROLE olmis_monitoring LOGIN PASSWORD '...';
GRANT pg_monitor TO olmis_monitoring;
```

## Notes

- `network_mode: host`, not the app network: the app deploy's
  `docker compose down` cannot remove `<env>_default` while a foreign container
  is attached to it. Container IPs on every bridge are reachable from the host.
- `COMPOSE_PROJECT_NAME` must stay `soldevelo-monitoring-agents`: `config.alloy`
  drops the agent's own logs by that project name.
- Labels: `app=openlmis`, `deployment=selv`, `environment` from the monitoring
  enum - Test=`staging`, Prod=`prod`.
- `test_env` runs Docker 19.03 (API 1.40): `DOCKER_API_VERSION=1.40` in
  `alloy.env` lets a newer docker CLI talk to it. `docker compose` negotiates by
  itself. It also cannot pull OCI-only images, which every Alloy release from
  v1.13 is, so `ALLOY_VERSION` stays at v1.12.2 until the host is on Docker
  20.10+.
