#!/usr/bin/env bash
# Seed the FIB-4 risk-stratification orderable concepts (VCTE, ELF, Consult)
# and their LOINC mappings on an OpenMRS server.
#
# Idempotent: skips a concept if a concept with the same fully-specified
# name already exists. Reads the manifest at openmrs/concepts/concepts.json.
#
# Required env (no defaults — fails loudly if unset):
#   OPENMRS_BASE_URL   e.g. https://your-host/openmrs
#   OPENMRS_USER       a user with the System Developer role
#   OPENMRS_PASSWORD
#
# Usage:
#   export OPENMRS_BASE_URL=...
#   export OPENMRS_USER=...
#   export OPENMRS_PASSWORD=...
#   ./openmrs/scripts/seed-concepts.sh

set -euo pipefail

: "${OPENMRS_BASE_URL:?set OPENMRS_BASE_URL}"
: "${OPENMRS_USER:?set OPENMRS_USER}"
: "${OPENMRS_PASSWORD:?set OPENMRS_PASSWORD}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/../concepts/concepts.json"
[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST" >&2; exit 1; }
command -v jq >/dev/null   || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

API="${OPENMRS_BASE_URL%/}/ws/rest/v1"
AUTH=(-u "${OPENMRS_USER}:${OPENMRS_PASSWORD}")

# Verify auth works before mutating anything.
auth_check=$(curl -fsS "${AUTH[@]}" "${API}/session" | jq -r '.authenticated')
[ "$auth_check" = "true" ] || { echo "authentication failed for ${OPENMRS_USER}" >&2; exit 1; }

resolve () {
  jq -r "$1" "$MANIFEST"
}

DT_NA=$(resolve '.datatypes.n_a')
LOINC=$(resolve '.sources.loinc')
SAME_AS=$(resolve '.map_types.same_as')

post_concept () {
  local key="$1"
  local fsn=$(resolve ".concepts[] | select(.key==\"$key\") | .fully_specified_name")
  local short=$(resolve ".concepts[] | select(.key==\"$key\") | .short_name")
  local desc=$(resolve ".concepts[] | select(.key==\"$key\") | .description")
  local class_key=$(resolve ".concepts[] | select(.key==\"$key\") | .concept_class")
  local class_uuid=$(resolve ".concept_classes.${class_key}")

  # Idempotency: skip if a concept with this fully-specified name exists.
  local existing
  existing=$(curl -fsS "${AUTH[@]}" \
    --data-urlencode "q=$fsn" --data-urlencode "v=default" -G "${API}/concept" \
    | jq -r --arg fsn "$fsn" '.results[] | select(.display==$fsn) | .uuid' | head -1)
  if [ -n "$existing" ]; then
    echo "skip ${key}: already exists ($existing)"
    echo "$existing"
    return 0
  fi

  local concept_uuid=$(resolve ".concepts[] | select(.key==\"$key\") | .uuid")

  local body
  body=$(jq -n \
    --arg uuid "$concept_uuid" \
    --arg fsn "$fsn" --arg short "$short" --arg desc "$desc" \
    --arg dt "$DT_NA" --arg cc "$class_uuid" \
    '{
      uuid: $uuid,
      names: [
        {name:$fsn,   locale:"en", localePreferred:true, conceptNameType:"FULLY_SPECIFIED"},
        {name:$short, locale:"en", conceptNameType:"SHORT"}
      ],
      descriptions: [{description:$desc, locale:"en"}],
      datatype: $dt,
      conceptClass: $cc,
      set: false
    }')

  curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" \
    -X POST -d "$body" "${API}/concept" \
    | jq -r '.uuid'
}

post_loinc_mapping () {
  local key="$1"
  local concept_uuid="$2"
  local code=$(resolve ".concepts[] | select(.key==\"$key\") | .loinc_code")
  local name=$(resolve ".concepts[] | select(.key==\"$key\") | .loinc_name")
  [ "$code" = "null" ] && return 0

  local term_body
  term_body=$(jq -n --arg src "$LOINC" --arg code "$code" --arg name "$name" \
    '{conceptSource:$src, code:$code, name:$name}')
  local term_uuid
  term_uuid=$(curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" \
    -X POST -d "$term_body" "${API}/conceptreferenceterm" | jq -r '.uuid')

  local map_body
  map_body=$(jq -n --arg term "$term_uuid" --arg type "$SAME_AS" \
    '{conceptReferenceTerm:$term, conceptMapType:$type}')
  curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" \
    -X POST -d "$map_body" "${API}/concept/${concept_uuid}/mapping" >/dev/null
  echo "  -> mapped LOINC ${code}"
}

for key in $(jq -r '.concepts[].key' "$MANIFEST"); do
  echo "== ${key} =="
  uuid=$(post_concept "$key")
  echo "  concept uuid: ${uuid}"
  post_loinc_mapping "$key" "$uuid" || true
done

echo "done."
