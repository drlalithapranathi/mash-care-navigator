# OpenMRS deploy runbook

This directory is the **reference** deployment for the FIB-4 widget: a portable,
reproducible `docker-compose.yml` for a fresh OpenMRS instance. Copy
`openmrs/.env.example` to `.env`, create the DB secrets (see
[`secrets/README.md`](secrets/README.md)), then `docker compose up -d`.

## Image pinning (#26)

Every image is digest-pinned so two `up -d` runs land on the identical build and
a `pull`/recreate can't silently change the distro under the widget:

| Service | Image |
| --- | --- |
| openmrs | `openmrs-reference-application-distro:demo@sha256:1088b9cb…` (coreapps 1.34.0, RefApp 2.13.x) |
| db | `mysql:8.0.40@sha256:d58ac933…` (override `MYSQL_IMAGE` to change) |
| nginx-proxy | `nginxproxy/nginx-proxy:1.6@sha256:5dd14e68…` |
| acme-companion | `nginxproxy/acme-companion:2.4@sha256:202fffa4…` |

The `demo` / `1.6` / `2.4` tags are only human-readable labels — the `@sha256`
digest is authoritative, so none of these behave as rolling tags. To move to a
new release, resolve its digest and set the override, e.g.:

```sh
docker manifest inspect openmrs/openmrs-reference-application-distro:2.14.0 \
  | sed -n 's/.*"digest": "\(sha256:[a-f0-9]*\)".*/\1/p' | head -1
# then set OPENMRS_IMAGE=openmrs/openmrs-reference-application-distro:2.14.0@sha256:<digest> in .env
```

## MySQL: off EOL 5.6 onto a supported line (#26)

`mysql:5.6` has had no security patches since Feb 2021. Fresh deploys default to
`mysql:8.0.40`. The **existing pilot box still runs 5.6**; 8.0 cannot read a 5.6
data volume in place, so migrate with a logical dump/restore against a backup:

```sh
# 1. Snapshot first (see scripts/backup-db.sh).
./openmrs/scripts/backup-db.sh

# 2. Dump from the running 5.6 container.
docker exec mash-openmrs-db sh -c \
  'mysqldump --single-transaction --routines --triggers -uroot -p"$MYSQL_ROOT_PASSWORD" openmrs' \
  | gzip > openmrs-5.6-dump.sql.gz

# 3. Bring up the 8.0 db on a FRESH volume, then load the dump.
#    (MYSQL_IMAGE defaults to 8.0.40; `docker compose up -d db`)
gunzip -c openmrs-5.6-dump.sql.gz | docker exec -i openmrs-db \
  sh -c 'mysql -uroot -p"$(cat /run/secrets/mysql_root_password)" openmrs'

# 4. Start OpenMRS with DB_AUTO_UPDATE=true once so Liquibase re-checks the
#    schema against the supported server, then set it back to false.
```

Notes:
- The `--default-authentication-plugin=mysql_native_password` flag in the compose
  keeps the RefApp's bundled JDBC connector working on 8.0. If you override
  `MYSQL_IMAGE` back to 5.x, remove that flag (5.6 rejects it).
- Re-test the widget's REST reads/writes after the cutover before decommissioning
  the 5.6 volume.
