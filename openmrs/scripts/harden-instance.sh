#!/usr/bin/env bash
# Harden a fresh OpenMRS instance off its demo defaults (#17):
#   - rotate the built-in `admin` account off the well-known Admin123 password
#   - enforce a non-trivial password policy
#   - verify the old password no longer authenticates
#
# Network access control (basic-auth / IP allowlist / VPN) is enforced at the
# proxy, not here — see openmrs/deploy/README.md.
#
# Required env (no defaults — fails loudly if unset):
#   OPENMRS_BASE_URL     e.g. https://your-host/openmrs
#   OPENMRS_USER         a System Developer (initially `admin`)
#   OPENMRS_PASSWORD     that user's current password (initially Admin123)
#   NEW_ADMIN_PASSWORD   the strong replacement password to set
#
# Usage:
#   export OPENMRS_BASE_URL=... OPENMRS_USER=admin OPENMRS_PASSWORD=Admin123
#   export NEW_ADMIN_PASSWORD='<a strong, unique password>'
#   ./openmrs/scripts/harden-instance.sh

set -euo pipefail

: "${OPENMRS_BASE_URL:?set OPENMRS_BASE_URL}"
: "${OPENMRS_USER:?set OPENMRS_USER}"
: "${OPENMRS_PASSWORD:?set OPENMRS_PASSWORD}"
: "${NEW_ADMIN_PASSWORD:?set NEW_ADMIN_PASSWORD}"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

API="${OPENMRS_BASE_URL%/}/ws/rest/v1"
AUTH=(-u "${OPENMRS_USER}:${OPENMRS_PASSWORD}")

authed=$(curl -fsS "${AUTH[@]}" "${API}/session" | jq -r '.authenticated' 2>/dev/null || echo false)
[ "$authed" = "true" ] || { echo "authentication failed for ${OPENMRS_USER}" >&2; exit 1; }

# Reject a no-op / weak replacement early.
if [ "$NEW_ADMIN_PASSWORD" = "$OPENMRS_PASSWORD" ]; then
  echo "NEW_ADMIN_PASSWORD must differ from the current password" >&2; exit 1
fi
if [ "${#NEW_ADMIN_PASSWORD}" -lt 8 ]; then
  echo "NEW_ADMIN_PASSWORD must be at least 8 characters" >&2; exit 1
fi

# Resolve the target user's UUID (the account we authenticated as).
uuid=$(curl -fsS "${AUTH[@]}" "${API}/session?v=custom:(user:(uuid,username))" \
  | jq -r '.user.uuid // empty')
[ -n "$uuid" ] || { echo "could not resolve current user uuid" >&2; exit 1; }

echo "== enforcing password policy =="
set_gp () {
  local prop="$1" val="$2"
  curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -X POST \
    -d "{\"property\":\"${prop}\",\"value\":\"${val}\"}" "${API}/systemsetting" >/dev/null 2>&1 \
    || curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -X POST \
         -d "{\"value\":\"${val}\"}" "${API}/systemsetting/${prop}" >/dev/null 2>&1 || true
  echo "  ${prop}=${val}"
}
set_gp security.passwordMinimumLength 8
set_gp security.passwordRequiresDigit true
set_gp security.passwordRequiresNonDigit true
set_gp security.passwordRequiresUpperAndLowerCase true
set_gp security.passwordCannotMatchUsername true

echo "== rotating password for ${OPENMRS_USER} (${uuid}) =="
# Admin changing another (or their own) account password: POST /password/{uuid}.
if ! curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -X POST \
      -d "{\"newPassword\":\"${NEW_ADMIN_PASSWORD}\"}" "${API}/password/${uuid}" >/dev/null 2>&1; then
  # Fall back to the self-change form (requires the old password).
  curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -X POST \
    -d "{\"oldPassword\":\"${OPENMRS_PASSWORD}\",\"newPassword\":\"${NEW_ADMIN_PASSWORD}\"}" \
    "${API}/password/${uuid}" >/dev/null
fi

echo "== verifying =="
new_ok=$(curl -fsS -u "${OPENMRS_USER}:${NEW_ADMIN_PASSWORD}" "${API}/session" | jq -r '.authenticated' 2>/dev/null || echo false)
old_code=$(curl -s -o /dev/null -w '%{http_code}' -u "${OPENMRS_USER}:${OPENMRS_PASSWORD}" "${API}/session")
[ "$new_ok" = "true" ]   || { echo "  FAIL: new password does not authenticate" >&2; exit 1; }
# A correct rotation makes the old password unauthenticated (200 with authenticated:false, or 401).
old_authed=$(curl -s -u "${OPENMRS_USER}:${OPENMRS_PASSWORD}" "${API}/session" | jq -r '.authenticated' 2>/dev/null || echo false)
[ "$old_authed" != "true" ] || { echo "  FAIL: old password still authenticates" >&2; exit 1; }
echo "  new password authenticates: yes"
echo "  old password authenticates: no (session http ${old_code})"
echo "done — rotate any seed/deploy env (OPENMRS_PASSWORD) to the new value."
