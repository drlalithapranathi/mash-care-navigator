#!/usr/bin/env bash
# Seed the global properties the FIB-4 widget reads to resolve concept / order
# UUIDs (issue #7). The widget falls back to the values hardcoded in
# widget/fib4screening.gsp if a property is unset, so seeding is optional — it
# makes a deployment portable (point the widget at a server's own concepts
# without editing the GSP).
#
# Required env (no defaults — fails loudly if unset):
#   OPENMRS_BASE_URL   e.g. https://your-host/openmrs
#   OPENMRS_USER       a user with privileges to manage global properties
#   OPENMRS_PASSWORD
#
# Usage:
#   export OPENMRS_BASE_URL=... OPENMRS_USER=... OPENMRS_PASSWORD=...
#   ./openmrs/scripts/seed-global-properties.sh

set -euo pipefail

: "${OPENMRS_BASE_URL:?set OPENMRS_BASE_URL}"
: "${OPENMRS_USER:?set OPENMRS_USER}"
: "${OPENMRS_PASSWORD:?set OPENMRS_PASSWORD}"

API="${OPENMRS_BASE_URL%/}/ws/rest/v1"
AUTH=(-u "${OPENMRS_USER}:${OPENMRS_PASSWORD}")

# property -> UUID (mirror the defaults in widget/fib4screening.gsp)
GP=(
  "mashmasld.concept.ast=5914052f-e777-4efc-949b-0dee321ae55f"
  "mashmasld.concept.alt=29a09214-cfd4-4db9-898e-f2a3e6f08feb"
  "mashmasld.concept.plat=8575950e-90bf-4530-9595-deebbdf2cdde"
  "mashmasld.order.cbc=30b29cc7-3565-11f1-a0a1-92c09ef48e9b"
  "mashmasld.order.hepatic=353d3e7b-3565-11f1-a0a1-92c09ef48e9b"
  "mashmasld.order.vcte=cb9450cf-bb90-4600-9116-b7c1ab8ee5b3"
  "mashmasld.order.elf=cd75cf42-ef4b-4d15-9ea4-ea12eca9e568"
  "mashmasld.order.consult=f682c646-b597-4cd4-8282-4191e0eb040b"
)

for entry in "${GP[@]}"; do
  prop="${entry%%=*}"; val="${entry##*=}"
  # POST creates the property (or updates it if it already exists).
  if curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -X POST \
       -d "{\"property\":\"${prop}\",\"value\":\"${val}\"}" \
       "${API}/systemsetting" >/dev/null 2>&1; then
    echo "  set ${prop}"
  else
    # Already present — update in place by property id.
    curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -X POST \
      -d "{\"value\":\"${val}\"}" "${API}/systemsetting/${prop}" >/dev/null \
      && echo "  updated ${prop}" || echo "  FAILED ${prop}"
  fi
done

echo "done."
