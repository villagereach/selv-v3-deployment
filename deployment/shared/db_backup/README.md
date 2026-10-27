# Database backup to S3 (db_backup)

Scheduled and manual backups of the OpenLMIS database to S3, with an on/off switch that does not
require editing the crontab. Used on the test server. Production uses the scripts in
`../backup_database`.

## How it works

- `db_backup.sh` streams `pg_dump` out of the database container straight into a zip file on the
  host. Nothing is written inside the container and no uncompressed copy is kept, so a run needs
  about the size of the zip in free space (a few GB for a typical database).
- The zip holds one plain SQL entry, the format `deployment/shared/restore.sh` expects.
- Before uploading, the script checks the exit codes of `pg_dump` and `zip`, the zip size
  (`MIN_BACKUP_MB`), that the zip has exactly one entry and, with `VERIFY_DUMP=true`, that pg_dump's
  completion line is at the end of the dump. Only then does it upload the file and compare its size
  in S3. Any failure stops the run with a non-zero exit code.
- The local zip is removed at the end of every run; leftovers of a killed run are removed at the
  start of the next one. If a run ends before pg_dump has finished, the script ends that pg_dump
  session in the database; otherwise it would keep running to the end for nothing.
- Backups go to prefixes in the bucket:

  | Prefix | Written by | Kept |
  |---|---|---|
  | `daily/` | scheduled run, most days | lifecycle rule, 7 days |
  | `weekly/` | scheduled run on `DAY_OF_WEEKLY_BACKUP` | lifecycle rule, 35 days |
  | `monthly/` | scheduled run on `DAY_OF_MONTHLY_BACKUP` | lifecycle rule if one is set, otherwise forever |
  | `manual/` | `backupctl run` | until deleted by hand |

- The scripts never delete anything in S3. Expiry is done by lifecycle rules on the bucket, so the
  server role needs no delete or list permission. Age-based expiry also removes the newest file once
  it is older than the limit: if scheduled runs stop, `daily/` is empty about 8 days later.
- The tier depends only on the date of the run. If the run on the monthly day fails or the switch
  is off that day, there is no monthly backup for that month.
- `/etc/cron.d/selv-db-backup` runs `backupctl cron` every day. `backupctl` reads the switch file
  and either runs the backup or only records the tick and logs `SKIP`. A missing or unreadable switch
  file counts as off. A lock prevents two backups at the same time.
- The Jenkins wipe of the test server restores from the bucket set in `BUCKET_NAME` of the test
  `settings.env`, not from this one, so the prefixes here do not affect it.

## Files

| File | Purpose |
|---|---|
| `db_backup.sh` | one backup run: `db_backup.sh auto` (daily/weekly/monthly) or `db_backup.sh manual` |
| `backupctl` | switch, status, manual run, stop, log, cron entry install |
| `backup.config.example` | settings; copy to `backup.config` on the server |
| `selv-db-backup.cron` | template for `/etc/cron.d/selv-db-backup`, rendered by `backupctl install` |

On the server, `backupctl` also creates `state/` (switch, last tick, last run, last success),
`logs/db_backup.log` and `work/` (the zip while a backup runs). Run both scripts as the user that
owns the folder (`ubuntu`), never with sudo: files created by root would break later runs.
`backupctl` calls sudo itself where it needs it.

## AWS setup

The EC2 instance role of the server needs this policy for its own bucket, in addition to anything
else the server uses:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TestBackupsUploadAndRead",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:AbortMultipartUpload"],
      "Resource": "arn:aws:s3:::<backup bucket>/*"
    }
  ]
}
```

With `AWS_USE_INSTANCE_ROLE=true` the scripts use only the instance role and ignore AWS credential
files and key variables. `PROTECTED_BUCKETS` lists buckets the script refuses to write to, as a guard
against a wrong `S3_BUCKET`.

Lifecycle rules on the bucket:

- `daily/`: expire current versions after 7 days
- `weekly/`: expire current versions after 35 days
- `monthly/`: optional, expire after the agreed period
- whole bucket: delete incomplete multipart uploads after 7 days, with no expiry action

## Install on a server

The folder is copied to the server by hand; no Jenkins job deploys it.

1. Copy this folder to the server, for example:
   `scp -r deployment/shared/db_backup <host>:~/db_backup`
2. Create the config and set every value, at least `S3_BUCKET`:
   `cp ~/db_backup/backup.config.example ~/db_backup/backup.config`
3. Check that the instance role works on its own:
   `AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_CONFIG_FILE=/dev/null ~/.local/bin/aws sts get-caller-identity --region eu-west-1`
   should print `assumed-role/<role name>/<instance id>`.
4. If the server used `../backup_database` before: save the crontab and remove its backup lines,
   including commented ones (`crontab -l > ~/crontab.before-db_backup && crontab -e`), then remove or
   rename `~/backup_database`. Its sync scripts mirror the bucket with `--delete`, and its local copy
   of the bucket takes disk space. `backupctl status` warns while any `backup_database/` line is
   left in the crontab.
5. Install the cron entry. The switch starts off:
   `~/db_backup/backupctl install`
6. Check that a backup works before turning the schedule on:
   `~/db_backup/backupctl run`, then `~/db_backup/backupctl log -f` and `~/db_backup/backupctl status`.
   This is the only step that tests the S3 upload. Its file stays in `manual/` until someone
   deletes it with other credentials, because the server role cannot delete.

## Updating

Copy the files from the repo over the ones on the server while no backup is running
(`backupctl status` shows `running now: no`). Overwriting a script while it runs can break the run.

```
scp deployment/shared/db_backup/* <host>:~/db_backup/
```

Copy the files, not the folder: `scp -r` into an existing `~/db_backup` creates
`~/db_backup/db_backup`. `backup.config`, `state/`, `logs/` and `work/` stay as they are. Run
`~/db_backup/backupctl install` again when `CRON_SCHEDULE` or the cron template has changed. Change
the scripts in the repo, not on the server, so that both copies stay the same.

## Turning it on and off

```
~/db_backup/backupctl on "<reason>"
~/db_backup/backupctl off "<reason>"
```

The change takes effect at the next cron time (`CRON_SCHEDULE`, UTC). No crontab editing and no
cron reload are needed. A reason is required and is kept in `state/switch` and in the log.

A backup that is running when the switch is turned off finishes. `~/db_backup/backupctl stop` ends
it now: it stops the whole run, nothing is uploaded, and the unfinished pg_dump is ended in the
database.

To stop the schedule completely, `~/db_backup/backupctl uninstall` removes the cron file;
`backupctl install` puts it back with the switch unchanged. If `backupctl` itself is broken,
`printf 'off\n' > ~/db_backup/state/switch` also turns it off.

## Manual backup

`~/db_backup/backupctl run` starts one backup into `manual/` in the background, also while the switch
is off. Use it before risky work on the server, such as upgrades or data scripts. Manual backups are
kept until someone deletes them in S3.

## Checking it

- `~/db_backup/backupctl status` prints the switch, the cron entry, the last cron tick, the last run
  and the last successful backup (manual runs count too). While the switch is on it warns when cron
  has not ticked for 25 hours, when the last run failed or when there has been no successful backup
  for 26 hours, and exits with 1.
- `~/db_backup/logs/db_backup.log` has every run and every SKIP. Results also go to the server's
  syslog with the tag `selv-db-backup`.
- The scripts send no notifications. Failures show in `backupctl status` (exit code 1), in the log
  and in syslog with the tag `selv-db-backup`, which monitoring can pick up.

## Restoring from a backup

The zip has a single entry named `-`, the pg_dump output streamed into zip.
`deployment/shared/restore.sh` accepts the file as `backup_file.sql.zip`. To restore by hand into an
empty database:

```
unzip -p open_lmis_<date>-<tier>.sql.zip | docker exec -i <db container> psql -U postgres -d open_lmis
```
