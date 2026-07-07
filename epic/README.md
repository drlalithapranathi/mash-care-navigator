# Epic (SMART on FHIR)

A standalone **SMART-on-FHIR web app** that screens for MASLD / MASH. It reads
a patient's labs and conditions from Epic and displays a FIB-4 risk
assessment. Read-only — it requests no write scopes.

Built with React + Vite + `fhirclient`. The same FIB-4 logic is implemented
for OpenMRS as a native dashboard widget under [`../openmrs`](../openmrs).

## Prerequisites

- Node.js.
- An Epic app registration and its client ID (see [Register the app](#1-register-the-app)).

## Setup

### 1. Register the app

At <https://fhir.epic.com> → **Build Apps**, create an app with:

| Setting       | Value |
|---------------|-------|
| Client type   | Public (browser SPA — PKCE required) |
| FHIR version  | R4 |
| Launch type   | Standalone (add EHR launch if needed) |
| Redirect URI  | the deployed `…/index.html`, matched exactly |
| Scopes        | `openid fhirUser launch/patient patient/Patient.read patient/Observation.read patient/Condition.read` |

Epic issues a **non-production client ID**; the sandbox activates it almost
immediately (production apps go through a separate review). The client ID is
not a secret, but keep it in `.env`, not in committed source.

### 2. Configure and run

```sh
cp .env.example .env.local   # set VITE_EPIC_CLIENT_ID
npm install
npm run dev
```

Open `launch.html` and sign in as a sandbox test patient. If the client ID is
blank, the page shows a reminder instead of launching.

## Sandbox reference

### Endpoints

Epic's public R4 sandbox (shared, no PHI):

| Endpoint             | URL |
|----------------------|-----|
| FHIR R4 base (`aud`) | `https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4` |
| Authorize            | `…/oauth2/authorize` |
| Token                | `…/oauth2/token` |

You configure only the base URL; `fhirclient` discovers the authorize and
token endpoints from `/.well-known/smart-configuration`.

### Test patients

Epic ships **fictional** sandbox test patients (synthetic data — no real PHI).
For a FIB-4 demo, use one that has lab results. The current roster and login
credentials are in Epic's
[Test Patients](https://fhir.epic.com/Documentation?docId=testpatients) docs.

Confirm the Observation results before a live demo — which patients carry the
AST / ALT / platelet values needed for FIB-4 can change over time.

## How it works

| File | Role |
|------|------|
| `launch.html` → `src/launch.js` | Starts the SMART auth (PKCE); redirects to Epic to sign in. |
| `index.html` → `src/main.jsx`   | Epic redirects back here; completes the token exchange and renders the app. |
| `src/utils/fhirHelpers.js`      | FHIR queries — fetches the latest AST / ALT / platelets / HbA1c / BMI. |
| `src/utils/fib4.js`, `riskAssessment.js` | FIB-4 score and risk tiers. |

### Epic-specific handling

The client already accounts for a few Epic FHIR behaviors:

- Observation search sends a `category` filter and a comma-separated `status`
  list, and sorts results client-side (Epic ignores `_sort=-date`).
- Condition search follows bundle paging, so no active problem is missed.
- A failed OAuth handshake is logged to the console rather than silently
  falling back to Demo Mode.
