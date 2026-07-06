# OpenMRS integration

Server-side artifacts for running MASH Care Navigator on OpenMRS Reference
Application 2.x:

- **`widget/fib4screening.gsp`** — the FIB-4 dashboard widget GSP, patched
  into `coreapps-1.34.0.omod` at
  `web/module/fragments/dashboardwidgets/fib4screening.gsp`.
- **`concepts/concepts.json`** — manifest of the concepts the widget relies
  on: the three orderables it posts (FibroScan (VCTE), Enhanced Liver
  Fibrosis (ELF), Gastroenterology / Hepatology consult) plus the HbA1c
  LOINC mapping and the BMI concept used in risk assessment, with LOINC
  mappings.
- **`deploy/docker-compose.yml`** — full stack: nginx-proxy + acme-companion +
  MySQL 5.6 + OpenMRS RefApp distro.
- **`deploy/repack-omod.py`** — rebuilds the coreapps OMOD with a replaced
  GSP, preserving zip directory entries (a naive repack drops them and
  silently breaks app discovery on the home page — Find Patient disappears).
- **`scripts/seed-concepts.sh`** — idempotent replay of the concept manifest
  against a fresh OpenMRS instance.

## Bring up the stack

```sh
cp openmrs/.env.example openmrs/.env
# edit openmrs/.env — set VIRTUAL_HOST, LETSENCRYPT_EMAIL,
# MYSQL_ROOT_PASSWORD, MYSQL_PASSWORD, OPENMRS_BASE_URL,
# OPENMRS_USER, OPENMRS_PASSWORD.

docker compose --env-file openmrs/.env -f openmrs/deploy/docker-compose.yml up -d
```

Wait for the OpenMRS container to finish first-run setup (a few minutes on
a fresh DB) before going to the next step.

## Seed the orderable concepts

The widget posts test orders against three concepts that don't ship with
the RefApp distro; the manifest also adds a LOINC mapping to the distro's
existing HbA1c concept and creates a numeric BMI concept. Seed once per
fresh server:

```sh
set -a; source openmrs/.env; set +a
./openmrs/scripts/seed-concepts.sh
```

The script is idempotent: if a concept with the same fully-specified name
already exists, it's skipped. `OPENMRS_USER` must hold the **System
Developer** role (concept creation requires it).

## Patch the coreapps OMOD

The widget GSP is shipped *inside* `coreapps-1.34.0.omod`. To deploy a new
version of the widget you rebuild the OMOD with the new GSP and drop it
into the OpenMRS bundled-modules dir.

```sh
# 1. Pull the current OMOD off the running container.
docker cp openmrs-app:/usr/local/tomcat/webapps/openmrs/WEB-INF/bundledModules/coreapps-1.34.0.omod \
    /tmp/coreapps-current.omod

# 2. Repack with the new GSP. The repacker fails loudly if any zip entry
#    drifts — it will not ship a broken OMOD.
python3 openmrs/deploy/repack-omod.py \
    /tmp/coreapps-current.omod \
    openmrs/widget/fib4screening.gsp \
    /tmp/coreapps-patched.omod

# 3. Back up the live OMOD, then deploy the new one.
docker cp openmrs-app:/usr/local/tomcat/webapps/openmrs/WEB-INF/bundledModules/coreapps-1.34.0.omod \
    /tmp/coreapps-pre-edit.omod
docker cp /tmp/coreapps-patched.omod \
    openmrs-app:/usr/local/tomcat/webapps/openmrs/WEB-INF/bundledModules/coreapps-1.34.0.omod

# 4. Restart so the new module is picked up. Tomcat lazily extracts the GSP
#    on first patient-page hit.
docker restart openmrs-app
```

### Rollback
```sh
docker cp /tmp/coreapps-pre-edit.omod \
    openmrs-app:/usr/local/tomcat/webapps/openmrs/WEB-INF/bundledModules/coreapps-1.34.0.omod
docker restart openmrs-app
```

## Widget behavior

`widget/fib4screening.gsp` renders on the patient clinician-facing dashboard.

1. Fetches latest AST, ALT, and platelets via `/ws/rest/v1/obs`.
2. **Missing labs** — shows an "Order Missing Labs" button. Clicking it
   does session → provider → visit (creating one if absent) → POST
   `/encounter` with CBC and/or Hepatic Function Panel test orders.
3. **All labs present** — calculates FIB-4:
   `(age × AST) / (platelets × √ALT)`
   Lower cutoff is age-adjusted: 1.3 by default, 2.0 for age ≥ 65.
4. **Risk-level actions:**
   - Low: continue standard care.
   - Intermediate: per-row "Place Order" buttons for FibroScan (VCTE) and
     ELF.
   - High: "Place Order" button for Gastroenterology / Hepatology consult.

   Each action button does the same encounter-POST flow as the missing-labs
   button, with an active-order check that surfaces "Already ordered /
   Awaiting result" when a prior order exists.

## Reference: deployed concept UUIDs

These UUIDs are reproduced by `seed-concepts.sh` on a fresh server (the
concepts are created with explicit UUIDs so they stay stable across rebuilds).

| Concept                                  | UUID                                   | LOINC    |
|------------------------------------------|----------------------------------------|----------|
| FibroScan (VCTE)                         | `cb9450cf-bb90-4600-9116-b7c1ab8ee5b3` | 79961-7  |
| Enhanced Liver Fibrosis (ELF) blood panel| `cd75cf42-ef4b-4d15-9ea4-ea12eca9e568` | 95942-6  |
| Gastroenterology / Hepatology consult    | `f682c646-b597-4cd4-8282-4191e0eb040b` | —        |
| Glycosylated Hemoglobin (existing distro concept, mapping added) | `b1c56e95-075a-47f3-8712-100c4d9efe1d` | 4548-4 |
| Body Mass Index                          | `4448c907-7fed-416c-9871-541b6c3b72b1` | 39156-5  |
