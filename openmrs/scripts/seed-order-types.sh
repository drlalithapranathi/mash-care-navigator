#!/usr/bin/env bash
# Make the MASLD orderables actually orderable, and place the GI/Hep consult
# under a referral order type instead of the test-order path (#24, #30).
#
# What it does:
#   1. Ensures a "MASLD Referral" order type exists and points
#      mashmasld.ordertype.referral at it. (OpenMRS REST cannot set an order
#      type's concept-class map, so the type is created with an empty map, which
#      OpenMRS treats as "all concept classes orderable" — the consult's Misc
#      Order class included.)
#   2. Verifies every orderable concept is orderable under the order type the
#      widget uses for it: a concept is orderable when the order type's class map
#      is empty (all allowed) or already contains the concept's class. If a
#      *restrictive* order type is missing a needed class, the script fails loudly
#      naming the class to add in Administration > Manage Order Types (REST offers
#      no way to edit the map, so this cannot be auto-configured).
#
# Idempotent: re-running is a no-op once configured.
#
# Required env (no defaults — fails loudly if unset):
#   OPENMRS_BASE_URL   e.g. https://your-host/openmrs
#   OPENMRS_USER       a user who can manage order types
#   OPENMRS_PASSWORD
#
# Usage:
#   export OPENMRS_BASE_URL=... OPENMRS_USER=... OPENMRS_PASSWORD=...
#   ./openmrs/scripts/seed-order-types.sh

set -euo pipefail

: "${OPENMRS_BASE_URL:?set OPENMRS_BASE_URL}"
: "${OPENMRS_USER:?set OPENMRS_USER}"
: "${OPENMRS_PASSWORD:?set OPENMRS_PASSWORD}"

command -v jq >/dev/null   || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

API="${OPENMRS_BASE_URL%/}/ws/rest/v1"
AUTH=(-u "${OPENMRS_USER}:${OPENMRS_PASSWORD}")

authed=$(curl -fsS "${AUTH[@]}" "${API}/session" | jq -r '.authenticated' 2>/dev/null || echo false)
[ "$authed" = "true" ] || { echo "authentication failed for ${OPENMRS_USER}" >&2; exit 1; }

TEST_ORDER_TYPE="52a447d3-a64a-11e3-9aeb-50e549534c5e"

VCTE="cb9450cf-bb90-4600-9116-b7c1ab8ee5b3"
ELF="cd75cf42-ef4b-4d15-9ea4-ea12eca9e568"
CONSULT="f682c646-b597-4cd4-8282-4191e0eb040b"
CBC="30b29cc7-3565-11f1-a0a1-92c09ef48e9b"
HEPATIC="353d3e7b-3565-11f1-a0a1-92c09ef48e9b"
HCC_US="a6a9a2d3-44a8-4207-91cd-9123c161302d"
VARICEAL="d47f8344-d5e9-4288-a40c-27d3484c22a7"

# ---- 1. Referral order type ----
REFERRAL_NAME="MASLD Referral"
referral_uuid=$(curl -fsS "${AUTH[@]}" -G "${API}/ordertype" \
  --data-urlencode "v=custom:(uuid,name)" \
  | jq -r --arg n "$REFERRAL_NAME" '.results[] | select(.name==$n) | .uuid' | head -1) || true
if [ -z "$referral_uuid" ] || [ "$referral_uuid" = "null" ]; then
  echo "== creating referral order type '${REFERRAL_NAME}' =="
  # REST rejects conceptClasses at create/edit; an empty map = all classes
  # orderable, which is what we want for the consult.
  body=$(jq -n --arg n "$REFERRAL_NAME" \
    '{name:$n, description:"Consult / referral orders for the MASLD (FIB-4) pathway",
      javaClassName:"org.openmrs.Order"}')
  referral_uuid=$(curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" \
    -X POST -d "$body" "${API}/ordertype" | jq -r '.uuid')
fi
[ -n "$referral_uuid" ] && [ "$referral_uuid" != "null" ] \
  || { echo "could not create or resolve the referral order type" >&2; exit 1; }
echo "  referral order type: ${referral_uuid}"

echo "== pointing mashmasld.ordertype.referral at it =="
curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -X POST \
  -d "{\"property\":\"mashmasld.ordertype.referral\",\"value\":\"${referral_uuid}\"}" \
  "${API}/systemsetting" >/dev/null 2>&1 \
  || curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -X POST \
       -d "{\"value\":\"${referral_uuid}\"}" \
       "${API}/systemsetting/mashmasld.ordertype.referral" >/dev/null 2>&1 || true
got=$(curl -fsS "${AUTH[@]}" "${API}/systemsetting/mashmasld.ordertype.referral?v=custom:(value)" \
  | jq -r '.value // empty' 2>/dev/null || echo "")
[ "$got" = "$referral_uuid" ] || { echo "  ERROR: referral GP did not store" >&2; exit 1; }

# ---- 2. Verify orderability ----
allowed_for () {
  curl -fsS "${AUTH[@]}" "${API}/ordertype/$1?v=custom:(conceptClasses:(uuid,name))" \
    | jq -c '[.conceptClasses[]? | {uuid, name}]'
}
class_of () {
  curl -fsS "${AUTH[@]}" "${API}/concept/$1?v=custom:(conceptClass:(uuid,name))" \
    | jq -c '.conceptClass // empty'
}

fail=0
check () {
  local concept="$1" otype="$2" label="$3" allowed cls cls_uuid cls_name
  allowed=$(allowed_for "$otype")
  cls=$(class_of "$concept")
  cls_uuid=$(echo "$cls" | jq -r '.uuid // empty')
  cls_name=$(echo "$cls" | jq -r '.name // "?"')
  if [ -z "$cls_uuid" ]; then
    echo "  FAIL ${label}: concept not found" >&2; fail=$((fail + 1)); return
  fi
  if [ "$(echo "$allowed" | jq 'length')" -eq 0 ] \
     || echo "$allowed" | jq -e --arg c "$cls_uuid" 'any(.uuid == $c)' >/dev/null; then
    echo "  OK   ${label} (class ${cls_name})"
  else
    echo "  FAIL ${label}: add the '${cls_name}' concept class to that order type in Manage Order Types" >&2
    fail=$((fail + 1))
  fi
}
echo "== verifying orderability =="
check "$VCTE"    "$TEST_ORDER_TYPE" "VCTE under Test Order"
check "$ELF"     "$TEST_ORDER_TYPE" "ELF under Test Order"
check "$CBC"     "$TEST_ORDER_TYPE" "CBC under Test Order"
check "$HEPATIC" "$TEST_ORDER_TYPE" "Hepatic under Test Order"
check "$HCC_US"  "$TEST_ORDER_TYPE" "HCC surveillance US under Test Order"
check "$VARICEAL" "$TEST_ORDER_TYPE" "Variceal EGD under Test Order"
check "$CONSULT" "$referral_uuid"   "Consult under referral"

[ "$fail" -eq 0 ] || { echo "${fail} orderable(s) not orderable under their order type." >&2; exit 1; }
echo "done — all MASLD orderables verified; referral order type ${referral_uuid} configured."
