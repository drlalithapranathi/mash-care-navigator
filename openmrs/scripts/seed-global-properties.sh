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

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
authed=$(curl -fsS "${AUTH[@]}" "${API}/session" | jq -r '.authenticated' 2>/dev/null || echo false)
[ "$authed" = "true" ] || { echo "authentication failed for ${OPENMRS_USER}" >&2; exit 1; }

# property -> UUID (mirror the defaults in widget/fib4screening.gsp)
GP=(
  "mashmasld.concept.ast=5914052f-e777-4efc-949b-0dee321ae55f"
  "mashmasld.concept.alt=29a09214-cfd4-4db9-898e-f2a3e6f08feb"
  "mashmasld.concept.plat=8575950e-90bf-4530-9595-deebbdf2cdde"
  "mashmasld.concept.deferred=87fcf943-1e0c-4b09-8771-23cae2affda3"
  "mashmasld.concept.fib4score=fd064e9b-a811-412d-9000-b7134db9d020"
  "mashmasld.concept.fib4category=a27e88f2-ab54-434c-952b-be714d1af6b0"
  "mashmasld.concept.deferralreason=99c8726a-e9cd-461f-b6f6-cd9cc0a166e1"
  "mashmasld.concept.deferralfollowup=f45d680b-811d-4955-aa5f-0d1a925f1cbc"
  "mashmasld.concept.fib4indication=11b4d295-be33-4f03-a7d5-d615513a5146"
  "mashmasld.concept.hba1c=b1c56e95-075a-47f3-8712-100c4d9efe1d"
  "mashmasld.concept.bmi=4448c907-7fed-416c-9871-541b6c3b72b1"
  "mashmasld.order.cbc=30b29cc7-3565-11f1-a0a1-92c09ef48e9b"
  "mashmasld.order.hepatic=353d3e7b-3565-11f1-a0a1-92c09ef48e9b"
  "mashmasld.order.vcte=cb9450cf-bb90-4600-9116-b7c1ab8ee5b3"
  "mashmasld.order.elf=cd75cf42-ef4b-4d15-9ea4-ea12eca9e568"
  "mashmasld.order.consult=f682c646-b597-4cd4-8282-4191e0eb040b"
  # Ordering metadata UUIDs — refapp defaults (mirror widget/fib4screening.gsp) (#25)
  "mashmasld.ordertype.test=52a447d3-a64a-11e3-9aeb-50e549534c5e"
  "mashmasld.caresetting.outpatient=6f0c9a92-6f24-11e3-af88-005056821db0"
  "mashmasld.encountertype.visitnote=d7151f82-c1f3-4152-a605-2f9ea7414a79"
  "mashmasld.visittype.facility=7b0f5697-27e3-40c4-8bae-f4049abfb4ed"
  # Encounter role for order/deferral provider attribution — Clinician (#29)
  "mashmasld.encounterrole=240b26f9-dd88-4172-823d-4a8bfeb7841f"
  # Optional inpatient mapping — no universal default, so seed only on instances
  # that have them; when both are set the widget picks the inpatient care setting
  # for orders placed on an active inpatient visit (#25):
  #   "mashmasld.caresetting.inpatient=<uuid>"
  #   "mashmasld.visittype.inpatient=<uuid>"
  # Referral order type for the GI/Hep consult (#30) is created and set by
  # seed-order-types.sh (it resolves the type's UUID at runtime). Left out here.
)

fail=0
for entry in "${GP[@]}"; do
  prop="${entry%%=*}"; val="${entry##*=}"
  # Create, or update in place if it already exists (a create POST 500s on a
  # pre-existing property, so fall through to the by-id update).
  curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -X POST \
    -d "{\"property\":\"${prop}\",\"value\":\"${val}\"}" "${API}/systemsetting" >/dev/null 2>&1 \
    || curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -X POST \
         -d "{\"value\":\"${val}\"}" "${API}/systemsetting/${prop}" >/dev/null 2>&1 || true
  # Verify by reading the stored value back — the only reliable success signal.
  got=$(curl -fsS "${AUTH[@]}" "${API}/systemsetting/${prop}?v=custom:(value)" | jq -r '.value // empty' 2>/dev/null || echo "")
  if [ "$got" = "$val" ]; then
    echo "  ok ${prop}"
  else
    echo "  FAILED ${prop} (stored '${got}', wanted '${val}')" >&2
    fail=$((fail + 1))
  fi
done

if [ "$fail" -gt 0 ]; then echo "${fail} property/properties failed." >&2; exit 1; fi
echo "done — ${#GP[@]} properties verified."
