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

## The widget as a reproducible, versioned artifact (#28)

The widget lives in git as a single GSP (`openmrs/widget/fib4screening.gsp`,
stamped with a version comment matching `openmrs/widget/VERSION`, visible in the
patient-chart page source so you can tell which build is live). The deployable is
that GSP patched into a base `coreapps` OMOD.

`repack-omod.py` is a **surgical single-entry replace**: it copies every original
zip entry — including the directory entries the module loader walks — through with
its `ZipInfo` unchanged and swaps only the target GSP's bytes, then asserts the
namelist is byte-identical and only that one file changed. No `os.walk` rebuild,
so no structural drift (the old rebuild-and-diff approach is gone).

Build a versioned artifact deterministically:

```sh
# base = the widget-REGISTERED coreapps from the running pinned container
docker cp mash-openmrs-app:/usr/local/tomcat/webapps/openmrs/WEB-INF/\
bundledModules/coreapps-1.34.0.omod openmrs/deploy/coreapps-1.34.0.omod
make -C openmrs/deploy omod        # -> coreapps-1.34.0+mashfib4-<VERSION>.omod
```

The base OMOD carries the dashboard-widget *registration* (which is not in the
GSP), so it must come from the registered module, not stock. Base OMOD and built
artifacts are gitignored — they are reproduced from git, not stored in it.

**Making a recreate/pull unable to revert the patch.** The current live deploy
`docker cp`s the patched OMOD into the container's `WEB-INF/bundledModules/`,
which lives only in the ephemeral writable layer — a `pull`/recreate reverts it.
To make the patch durable, drop the built OMOD into the persistent
`openmrs-data` volume's module dir instead, where OpenMRS loads it and it
survives recreate:

```sh
docker cp coreapps-1.34.0+mashfib4-<VERSION>.omod \
  mash-openmrs-app:/root/.OpenMRS/modules/coreapps-1.34.0.omod
docker restart mash-openmrs-app
```

Since the artifact filename encodes `VERSION` and the GSP carries the matching
comment, the live widget always corresponds to an identifiable version.
