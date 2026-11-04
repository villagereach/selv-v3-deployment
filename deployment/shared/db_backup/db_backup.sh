#!/usr/bin/env bash
#
# Dumps the OpenLMIS database into a zip file and uploads it to S3.
#
# Usage: db_backup.sh <auto|manual>
#   auto    daily, weekly or monthly backup, picked by the date (cron runs this through backupctl)
#   manual  one-off backup into the manual/ prefix, kept until someone deletes it
#
# pg_dump output is streamed out of the database container straight into the zip on the host,
# so nothing is written inside the container and no uncompressed copy is kept. The zip holds one
# plain SQL entry, the format deployment/shared/restore.sh expects. Nothing is uploaded unless the
# dump and the checks pass, and every failure exits non-zero. On exit the local zip is removed and
# an unfinished pg_dump is ended in the database, because it would otherwise run on to the end.
# Run it through backupctl, as the backup user. Settings come from backup.config next to this
# script (see backup.config.example).

set -euo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$BASE_DIR/backup.config"
WORK_DIR="$BASE_DIR/work"
# pg_dump sessions started by this script carry this application_name prefix.
APP_PREFIX=db_backup_

log() { printf '%s [db_backup] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
fail() { log "FAILED: $*"; exit 1; }
usage() { echo "Usage: $0 <auto|manual>" >&2; exit 2; }

[ $# -eq 1 ] || usage
MODE="$1"
[ "$(id -u)" -ne 0 ] || fail "run this as the backup user, not as root"

[ -r "$CONFIG_FILE" ] || fail "config file $CONFIG_FILE not found (copy backup.config.example)"
# shellcheck source-path=SCRIPTDIR source=backup.config.example
. "$CONFIG_FILE"

for var in POSTGRES_CONTAINER_NAME DATABASE_NAME DATABASE_USER S3_BUCKET AWS_REGION AWS_CLI \
           BACKUP_NAME_PREFIX DAY_OF_MONTHLY_BACKUP DAY_OF_WEEKLY_BACKUP MIN_FREE_GB MIN_BACKUP_MB; do
  [ -n "${!var:-}" ] || fail "$var is not set in $CONFIG_FILE"
done
for var in VERIFY_DUMP AWS_USE_INSTANCE_ROLE; do
  case "${!var:-true}" in
    true|false) ;;
    *) fail "$var must be true or false, got '${!var}'" ;;
  esac
done
for var in DAY_OF_MONTHLY_BACKUP DAY_OF_WEEKLY_BACKUP MIN_FREE_GB MIN_BACKUP_MB; do
  case "${!var}" in
    *[!0-9]*) fail "$var must be a whole number, got '${!var}'" ;;
  esac
  # Read as decimal, so that a leading zero (08) is not taken as octal.
  printf -v "$var" '%d' "$((10#${!var}))"
done
[ "$DAY_OF_MONTHLY_BACKUP" -ge 1 ] && [ "$DAY_OF_MONTHLY_BACKUP" -le 28 ] ||
  fail "DAY_OF_MONTHLY_BACKUP must be between 1 and 28"
[ "$DAY_OF_WEEKLY_BACKUP" -ge 1 ] && [ "$DAY_OF_WEEKLY_BACKUP" -le 7 ] ||
  fail "DAY_OF_WEEKLY_BACKUP must be between 1 and 7"

# One timestamp for every date field, so a run that starts at midnight cannot mix two days.
now=$(date -u +%s)
today=$(date -u -d "@$now" +%Y-%m-%d)
case "$MODE" in
  auto)
    if [ "$((10#$(date -u -d "@$now" +%d)))" -eq "$DAY_OF_MONTHLY_BACKUP" ]; then
      tier=monthly
    elif [ "$(date -u -d "@$now" +%u)" -eq "$DAY_OF_WEEKLY_BACKUP" ]; then
      tier=weekly
    else
      tier=daily
    fi
    name="${BACKUP_NAME_PREFIX}_${today}-${tier}.sql.zip"
    ;;
  manual)
    tier=manual
    name="${BACKUP_NAME_PREFIX}_$(date -u -d "@$now" +%Y-%m-%dT%H%M%SZ)-manual.sql.zip"
    ;;
  *)
    usage
    ;;
esac
key="$tier/$name"

case "$S3_BUCKET" in
  ""|*[!a-z0-9.-]*) fail "S3_BUCKET must be a bare bucket name, got '$S3_BUCKET'" ;;
esac
for protected in ${PROTECTED_BUCKETS:-}; do
  [ "$S3_BUCKET" != "$protected" ] || fail "refusing to write to protected bucket $protected"
done

if [ "${AWS_USE_INSTANCE_ROLE:-true}" = true ]; then
  # Use only the EC2 instance role: ignore AWS credential files and key variables.
  export AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_CONFIG_FILE=/dev/null
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_DEFAULT_PROFILE
fi
aws() { "$AWS_CLI" --region "$AWS_REGION" "$@"; }

[ -x "$AWS_CLI" ] || fail "AWS CLI not found at $AWS_CLI"
running=$(docker inspect -f '{{.State.Running}}' "$POSTGRES_CONTAINER_NAME" 2>/dev/null || true)
[ "$running" = true ] || fail "container $POSTGRES_CONTAINER_NAME is not running"

# Ends the pg_dump sessions of this script on DATABASE_NAME and prints how many, or "?" if psql failed.
# Only one backup runs at a time (work lock), so any such session that is still there is ours or orphaned.
end_dumps() {
  docker exec "$POSTGRES_CONTAINER_NAME" psql -U "$DATABASE_USER" -d "$DATABASE_NAME" -Atc \
    "SELECT count(pg_terminate_backend(pid)) FROM pg_stat_activity
     WHERE left(application_name, ${#APP_PREFIX}) = '$APP_PREFIX'
       AND datname = current_database() AND pid <> pg_backend_pid()" \
    2>/dev/null || echo "?"
}

mkdir -p "$WORK_DIR"
exec 8> "$WORK_DIR/.lock"
flock -n 8 || fail "another backup is running (lock $WORK_DIR/.lock)"

part="$WORK_DIR/$name.part"
app_name="$APP_PREFIX$$"
dump_started=false
dump_done=false
# zip writes through a temporary zi* file in the same directory. With the lock held, leftovers of an
# earlier run that was killed can go, and so can its pg_dump if it is still running.
rm -f "$WORK_DIR"/*.part "$WORK_DIR"/zi*
ended=$(end_dumps)
case "$ended" in
  0) ;;
  "?") log "could not check for pg_dump sessions left over from an earlier run" ;;
  *) log "ended $ended pg_dump session(s) left over from an earlier run" ;;
esac
cleanup() {
  local ended
  if [ "$dump_started" = true ] && [ "$dump_done" = false ]; then
    ended=$(end_dumps)
    if [ "$ended" = "?" ]; then
      log "could not end the unfinished pg_dump: check pg_stat_activity for application_name $app_name"
    else
      log "ended $ended unfinished pg_dump session(s) in $POSTGRES_CONTAINER_NAME"
    fi
  fi
  rm -f "$part" "$WORK_DIR"/zi*
}
trap cleanup EXIT
trap 'log "stopped by a signal"; exit 143' INT TERM

free_kb=$(df -Pk "$WORK_DIR" | awk 'NR == 2 { print $4 }')
[ "$free_kb" -ge $((MIN_FREE_GB * 1024 * 1024)) ] ||
  fail "only $((free_kb / 1024 / 1024)) GB free in $WORK_DIR, need $MIN_FREE_GB GB"

log "starting $tier backup of $DATABASE_NAME ($POSTGRES_CONTAINER_NAME) to s3://$S3_BUCKET/$key"
started=$(date -u +%s)
dump_started=true

set +e
docker exec -e PGAPPNAME="$app_name" "$POSTGRES_CONTAINER_NAME" \
  pg_dump -U "$DATABASE_USER" --lock-wait-timeout=10min "$DATABASE_NAME" | zip -q "$part" -
status=("${PIPESTATUS[@]}")
set -e
# docker exec returns pg_dump's exit code, so 0 means pg_dump finished in the container.
[ "${status[0]}" -ne 0 ] || dump_done=true
[ "${status[1]}" -eq 0 ] || fail "zip exited with ${status[1]} (pg_dump: ${status[0]})"
[ "${status[0]}" -eq 0 ] || fail "pg_dump exited with ${status[0]}"

bytes=$(stat -c %s "$part")
[ "$bytes" -ge $((MIN_BACKUP_MB * 1024 * 1024)) ] ||
  fail "the zip has only $bytes bytes, less than MIN_BACKUP_MB=$MIN_BACKUP_MB"
entries=$(unzip -Z1 "$part" | wc -l) || fail "cannot list the entries of the zip"
[ "$entries" -eq 1 ] || fail "the zip holds $entries entries, restore.sh needs exactly one"

if [ "${VERIFY_DUMP:-true}" = true ]; then
  # pg_dump writes this line near the very end of a complete plain dump.
  trailer=$(unzip -p "$part" | tail -c 2048) || fail "could not read the zip back"
  case "$trailer" in
    *"PostgreSQL database dump complete"*) ;;
    *) fail "the dump has no completion line, so it is incomplete" ;;
  esac
fi
log "dump ready: $bytes bytes after $(($(date -u +%s) - started)) s, uploading"

aws s3 cp "$part" "s3://$S3_BUCKET/$key" --only-show-errors || fail "upload to s3://$S3_BUCKET/$key failed"
remote=$(aws s3api head-object --bucket "$S3_BUCKET" --key "$key" --query ContentLength --output text) ||
  fail "cannot read back s3://$S3_BUCKET/$key"
[ "$remote" = "$bytes" ] || fail "size mismatch for s3://$S3_BUCKET/$key: local $bytes, S3 $remote"

log "OK: $tier backup s3://$S3_BUCKET/$key, $bytes bytes, $(($(date -u +%s) - started)) s"
if [ -n "${BACKUP_RESULT_FILE:-}" ]; then
  printf 'tier=%s key=%s bytes=%s\n' "$tier" "$key" "$bytes" > "$BACKUP_RESULT_FILE"
fi
