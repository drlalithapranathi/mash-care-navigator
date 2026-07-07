#!/usr/bin/env bash
# Seed concepts and LOINC mappings the MASH Care Navigator app needs in
# OpenMRS. Reads the manifest at openmrs/concepts/concepts.json.
#
# Each manifest entry is one of two kinds:
#   - new concept:       has `uuid` and concept_class/datatype — created if
#                        absent, with the supplied UUID pinned.
#   - existing concept:  has `existing_uuid` only — concept already lives in
#                        the OpenMRS dictionary (e.g. a refapp default like
#                        Glycosylated Hemoglobin); the script just adds the
#                        LOINC mapping if missing.
#
# Idempotent end-to-end: re-running is a no-op once seeded.
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

auth_check=$(curl -fsS "${AUTH[@]}" "${API}/session" | jq -r '.authenticated')
[ "$auth_check" = "true" ] || { echo "authentication failed for ${OPENMRS_USER}" >&2; exit 1; }

resolve () {
  jq -r "$1" "$MANIFEST"
}

# Resolve the LOINC concept source at runtime; the manifest UUID is only a
# fallback (a pinned source UUID 500s on servers where LOINC has a different
# UUID or none) (#32).
LOINC=$(curl -fsS "${AUTH[@]}" \
  --data-urlencode "q=LOINC" --data-urlencode "v=custom:(uuid,name,hl7Code)" -G "${API}/conceptsource" \
  | jq -r '.results[]? | select((.name // "" | ascii_upcase | contains("LOINC")) or (.hl7Code // "" | ascii_upcase == "LN")) | .uuid' | head -1)
if [ -z "$LOINC" ] || [ "$LOINC" = "null" ]; then
  LOINC=$(resolve '.sources.loinc')
  echo "  (LOINC source not found via API; falling back to manifest UUID ${LOINC})" >&2
fi
[ -n "$LOINC" ] && [ "$LOINC" != "null" ] || { echo "no LOINC concept source available" >&2; exit 1; }
SAME_AS=$(resolve '.map_types.same_as')

# -- create concept (if needed) and return its uuid --
post_concept () {
  local key="$1"
  local existing_uuid=$(resolve ".concepts[] | select(.key==\"$key\") | .existing_uuid // empty")
  if [ -n "$existing_uuid" ]; then
    # Confirm the pre-existing concept actually exists before mapping onto it (#32).
    if ! curl -fsS "${AUTH[@]}" "${API}/concept/${existing_uuid}?v=custom:(uuid)" >/dev/null 2>&1; then
      echo "  ERROR: existing_uuid concept not found: ${existing_uuid} (${key})" >&2
      return 1
    fi
    echo "$existing_uuid"
    return 0
  fi

  local fsn=$(resolve ".concepts[] | select(.key==\"$key\") | .fully_specified_name")
  local short=$(resolve ".concepts[] | select(.key==\"$key\") | .short_name")
  local desc=$(resolve ".concepts[] | select(.key==\"$key\") | .description")
  local class_key=$(resolve ".concepts[] | select(.key==\"$key\") | .concept_class")
  local dt_key=$(resolve ".concepts[] | select(.key==\"$key\") | .datatype")
  local class_uuid=$(resolve ".concept_classes.${class_key}")
  local dt_uuid=$(resolve ".datatypes.${dt_key}")
  local concept_uuid=$(resolve ".concepts[] | select(.key==\"$key\") | .uuid")

  # Skip if the pinned-UUID concept already exists. Keying on the pinned UUID
  # (not an FSN name-search) is deterministic and index-independent — a fresh
  # create is instantly a no-op on re-run, and a same-named dictionary concept
  # is never adopted in place of the UUID the widget/GPs actually query.
  if curl -fsS "${AUTH[@]}" "${API}/concept/${concept_uuid}?v=custom:(uuid)" >/dev/null 2>&1; then
    echo "  skip create ${key}: already exists (${concept_uuid})" >&2
    echo "$concept_uuid"
    return 0
  fi

  local body
  body=$(jq -n \
    --arg uuid "$concept_uuid" \
    --arg fsn "$fsn" --arg short "$short" --arg desc "$desc" \
    --arg dt "$dt_uuid" --arg cc "$class_uuid" \
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

# -- ensure LOINC mapping (idempotent: skip if concept already maps to code) --
post_loinc_mapping () {
  local key="$1"
  local concept_uuid="$2"
  local code=$(resolve ".concepts[] | select(.key==\"$key\") | .loinc_code")
  local name=$(resolve ".concepts[] | select(.key==\"$key\") | .loinc_name // \"\"")
  if [ "$code" = "null" ] || [ -z "$code" ]; then
    return 0
  fi

  # Already mapped? Match on the mapping's display prefix, which is rendered
  # by OpenMRS as "<source>: <code> (<term name>)" and is reliably present in
  # the v=full response (the conceptReferenceTerm sub-object is only a stub
  # there and does not carry .code).
  local prefix="LOINC: ${code} "
  local already
  already=$(curl -fsS "${AUTH[@]}" "${API}/concept/${concept_uuid}?v=full" \
    | jq -r --arg p "$prefix" '.mappings[]? | select(.display | startswith($p)) | .uuid' \
    | head -1) || true
  if [ -n "$already" ]; then
    echo "  skip mapping ${code}: already on concept"
    return 0
  fi

  # Reuse an existing reference term for this code if one exists; otherwise
  # create one. OpenMRS rejects duplicate (source, code) pairs with a 500.
  local term_uuid
  term_uuid=$(curl -fsS "${AUTH[@]}" \
    --data-urlencode "q=$code" --data-urlencode "v=default" \
    -G "${API}/conceptreferenceterm" \
    | jq -r --arg code "$code" --arg src "$LOINC" \
        '.results[]? | select(.code==$code) | .uuid' \
    | head -1) || true
  if [ -z "$term_uuid" ]; then
    local term_body
    term_body=$(jq -n --arg src "$LOINC" --arg code "$code" --arg name "$name" \
      '{conceptSource:$src, code:$code, name:$name}')
    term_uuid=$(curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" \
      -X POST -d "$term_body" "${API}/conceptreferenceterm" | jq -r '.uuid')
  fi
  if [ -z "$term_uuid" ] || [ "$term_uuid" = "null" ]; then
    echo "  ERROR: could not create or find LOINC reference term for ${code}" >&2
    return 1
  fi

  local map_body
  map_body=$(jq -n --arg term "$term_uuid" --arg type "$SAME_AS" \
    '{conceptReferenceTerm:$term, conceptMapType:$type}')
  if curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" \
       -X POST -d "$map_body" "${API}/concept/${concept_uuid}/mapping" >/dev/null; then
    echo "  -> mapped LOINC ${code}"
  else
    echo "  ERROR: failed to map LOINC ${code} to ${concept_uuid}" >&2
    return 1
  fi
}

fail=0
for key in $(jq -r '.concepts[].key' "$MANIFEST"); do
  echo "== ${key} =="
  uuid=$(post_concept "$key")
  echo "  concept uuid: ${uuid}"
  post_loinc_mapping "$key" "$uuid" || fail=$((fail + 1))
done

if [ "$fail" -gt 0 ]; then echo "${fail} concept(s) had LOINC mapping failures." >&2; exit 1; fi
echo "done."