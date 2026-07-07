#!/usr/bin/env bash
# Back up the OpenMRS MySQL database to a dated, gzipped dump stored OFF the
# db-data Docker volume (issue #18). Run from the deploy host or from cron.
#
# The DB password is read from inside the db container's own environment
# (MYSQL_ROOT_PASSWORD, passed to mysqldump via MYSQL_PWD), so no credential is
# passed on the host command line or stored in this script.
#
# Env (all optional; defaults match the compose stack):
#   DB_CONTAINER    default: mash-openmrs-db
#   MYSQL_DATABASE  default: openmrs
#   BACKUP_DIR      default: ./db-backups   (keep this OFF the Docker data volume)
#   RETENTION_DAYS  default: 14
#
# Cron example (daily 02:30, keep 14 days of dumps):
#   30 2 * * *  BACKUP_DIR=/home/plhi/db-backups /home/plhi/mash-openmrs/backup-db.sh
#
# Restore (DESTRUCTIVE — overwrites the target database):
#   gunzip -c db-backups/openmrs-YYYYmmdd-HHMMSS.sql.gz \
#     | docker exec -i mash-openmrs-db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -u root openmrs'
#   Then rebuild the Lucene search index so SQL-restored patients are findable:
#     curl -u <admin> -X POST <base>/ws/rest/v1/searchindexupdate

set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-mash-openmrs-db}"
MYSQL_DATABASE="${MYSQL_DATABASE:-openmrs}"
BACKUP_DIR="${BACKUP_DIR:-./db-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
docker ps --format '{{.Names}}' | grep -qx "$DB_CONTAINER" \
  || { echo "db container not running: ${DB_CONTAINER}" >&2; exit 1; }

mkdir -p "$BACKUP_DIR"
stamp=$(date -u +%Y%m%d-%H%M%S)
out="${BACKUP_DIR%/}/${MYSQL_DATABASE}-${stamp}.sql.gz"
tmp="${out}.partial"

# --single-transaction gives a consistent, non-locking dump for InnoDB tables.
if docker exec -e BK_DB="$MYSQL_DATABASE" "$DB_CONTAINER" \
     sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump -u root --single-transaction --routines --triggers "$BK_DB"' \
   | gzip > "$tmp"; then
  mv "$tmp" "$out"
  echo "backup: ${out} ($(du -h "$out" | cut -f1))"
else
  rm -f "$tmp"
  echo "backup FAILED" >&2
  exit 1
fi

# Retention: prune dumps older than RETENTION_DAYS.
find "$BACKUP_DIR" -maxdepth 1 -type f -name "${MYSQL_DATABASE}-*.sql.gz" \
     -mtime +"${RETENTION_DAYS}" -print -delete | sed 's/^/pruned: /' || true

echo "done."
