/**
 * SMART on FHIR launch entry point.
 *
 * Two paths, auto-detected from the URL:
 *  - EHR launch     — the EHR opens this page with ?iss=…&launch=…; fhirclient
 *                     reads iss from the URL, so we request the `launch` scope.
 *  - Standalone     — opened directly (e.g. Epic sandbox, patient signs in);
 *                     no iss in the URL, so we supply it and request
 *                     `launch/patient` to trigger patient selection.
 *
 * Config comes from Vite env vars (see .env.example). The client ID is a
 * placeholder until you register the app and fill VITE_EPIC_CLIENT_ID — it is
 * not a secret, but keep it in .env, not in committed source.
 */
import FHIR from 'fhirclient';

const env = import.meta.env;
const clientId = env.VITE_EPIC_CLIENT_ID || '';
const fhirBaseUrl =
  env.VITE_EPIC_FHIR_BASE ||
  'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4';

// EHR launch arrives with ?iss=&launch= on the URL; standalone has neither.
const iss = new URLSearchParams(window.location.search).get('iss');

const readScopes =
  'openid fhirUser patient/Patient.read patient/Observation.read patient/Condition.read';
const scope =
  env.VITE_EPIC_SCOPE || `${iss ? 'launch' : 'launch/patient'} ${readScopes}`;

function showMessage(html) {
  const box = document.getElementById('launch-message');
  if (box) box.innerHTML = html;
}

if (!clientId) {
  showMessage(
    'Set <code>VITE_EPIC_CLIENT_ID</code> in <code>.env.local</code> ' +
      '(copy from <code>.env.example</code>), then reload. ' +
      'See the repository README.'
  );
} else {
  FHIR.oauth2
    .authorize({
      clientId,
      scope,
      redirectUri: './index.html',
      // Standalone must name the server; EHR launch takes it from ?iss=.
      ...(iss ? {} : { iss: fhirBaseUrl }),
    })
    .catch((err) => {
      console.error('[SMART] authorize() failed:', err);
      showMessage(
        'Could not start the SMART launch. Check the client ID, redirect URI, ' +
          'and scopes against your Epic app registration. See the browser console.'
      );
    });
}
