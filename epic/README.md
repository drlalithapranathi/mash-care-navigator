# Epic integration (SMART on FHIR)

Runs the **same read-only SMART-on-FHIR client** in `web/` against an Epic
EHR instead of OpenMRS. Same logic — FIB-4 calculation, LOINC-based lab
matching, and the low / intermediate / high risk tiers — no code fork. Epic
is reached through the standard SMART launch; the only differences are app
registration, OAuth config, and a few FHIR-query quirks Epic enforces that
the current client doesn't yet handle.

> **Read-only on Epic.** The `web/` client never writes to FHIR — it reads
> Observations / Conditions and computes recommendations for display. The
> one-click *ordering* flow lives only in the OpenMRS widget
> (`openmrs/widget/fib4screening.gsp`), which posts encounters through the
> OpenMRS REST API, not FHIR. So Epic's tight restrictions on order-write
> scopes never come into play here — nothing to request, nothing to get
> denied.

## Sandbox endpoints

Epic's public R4 sandbox (shared, no PHI):

| Purpose            | URL |
|--------------------|-----|
| FHIR R4 base (`aud`) | `https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4` |
| Authorize          | `https://fhir.epic.com/interconnect-fhir-oauth/oauth2/authorize` |
| Token              | `https://fhir.epic.com/interconnect-fhir-oauth/oauth2/token` |
| SMART discovery    | append `/.well-known/smart-configuration` to the base |

Don't hardcode authorize/token — let `fhirclient` read them from the SMART
discovery document. The `aud` parameter on `authorize()` must equal the FHIR
base URL exactly.

## Register the app

At <https://fhir.epic.com> → **Build Apps** → create an app:

1. **Client type:** Public (a browser SPA can't hold a secret) → this makes
   **PKCE required**. `fhirclient` 2.5.4 handles the PKCE challenge itself.
2. **FHIR version:** R4.
3. **Launch:** enable **Standalone Launch** (app-initiated, user picks the
   patient) and, if you want the in-EHR path later, **EHR Launch** too.
4. **Redirect URI:** the exact deployed URL of `web/`'s redirect page
   (e.g. the built `index.html`). Must match byte-for-byte.
5. **Incoming APIs / scopes:** select the read resources listed below.
6. Save. Epic issues a **non-production client ID** — activation in the
   sandbox is near-immediate (production IDs go through a separate review).
   Put that ID in your local config (below); it is not a secret, but keep it
   in `.env`, not in committed source.

## Scopes

Epic sandbox speaks SMART **v1** scopes. Request only what the client reads:

```
openid fhirUser
launch/patient
patient/Patient.read
patient/Observation.read
patient/Condition.read
```

Notes:
- `launch/patient` is for **standalone** launch (prompts patient selection).
  For EHR launch use plain `launch` instead.
- **Drop `MedicationRequest.read`** — the current client never reads
  medications, so requesting it only adds a consent line and a denial risk.
- No write scopes. See the read-only note above.

## Test patients

Sign in at the OAuth prompt with Epic's published sandbox credentials.
**Camila Lopez** has the richest chart (labs incl. liver-panel-type
observations) and is the one to use for a FIB-4 demo:

| Patient        | MyChart login | Password   | Notes |
|----------------|---------------|------------|-------|
| Camila Lopez   | `fhircamila`  | `epicepic1`| Richest labs — use for FIB-4 |
| Derrick Lin    | `fhirderrick` | `epicepic1`| |
| Desiree Powell | `fhirdesiree` | `epicepic1`| |

(These are Epic's own public sandbox logins, documented at
<https://fhir.epic.com> → *Sandbox Test Data* / *Test Patients* — not MASH
credentials.) Whether a given sandbox patient has AST / ALT / platelet
values sufficient to compute FIB-4 changes over time, so confirm in the
Observation results before relying on a specific patient for a live demo;
the sandbox is built to prove connectivity, not to model realistic disease.

## What's already wired up

The `web/` client is set up to run against Epic — you just add the client ID.
These changes are in the tree:

- **Launch entry point** — `web/launch.html` + `web/src/launch.js` call
  `FHIR.oauth2.authorize(...)`, reading the client ID / FHIR base / scopes from
  Vite env (`web/.env.example`). It auto-detects **standalone** vs **EHR**
  launch (from `?iss=` on the URL) and requests `launch/patient` or `launch`
  accordingly. `web/vite.config.js` already builds `launch.html` as an entry.
- **Observation `status` filter** — now a comma OR-list
  (`status=final,amended,corrected`). Repeated `status=` params are **AND** in
  FHIR search and would have matched nothing.
- **No reliance on `_sort=-date`** — Epic ignores descending date sort, so the
  client fetches a date-windowed page with `category=laboratory` (liver labs +
  HbA1c) / `category=vital-signs` (BMI) and sorts client-side to pick the
  latest, instead of trusting the first bundle entry.
- **Condition paging** — the active-conditions query follows every `next` link
  (`pageLimit: 0`), so a risk factor (T2DM, obesity, …) past page 1 isn't lost.
- **OAuth errors surfaced** — `web/src/main.jsx` no longer silently swallows a
  failed handshake; a launch that carries OAuth params but fails logs to the
  console instead of hiding as a blank Demo Mode screen.

The status / sort / paging fixes also improve correctness against OpenMRS.

## Run it

Register the app for a non-production client ID, then:

```sh
cp web/.env.example web/.env.local   # set VITE_EPIC_CLIENT_ID
cd web && npm install && npm run dev
# open launch.html and sign in as a sandbox test patient
```

Left blank, `launch.html` shows a "set the client ID" message instead of
launching.