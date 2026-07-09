import React from 'react';
import ReactDOM from 'react-dom/client';
import FHIR from 'fhirclient';
import App from './App';
import './index.css';

/**
 * SMART on FHIR entry point.
 *
 * Launch types supported:
 *  1. EHR Launch    — Cerner/Epic opens launch.html → redirects here with auth code.
 *  2. OpenMRS OWA   — opened from the dashboard widget with ?patientId=<uuid>. No SMART
 *                     launch, so we build a standalone client against OpenMRS's own FHIR2
 *                     endpoint, authenticated by the same-origin logged-in session cookie.
 *  3. Standalone    — opened directly with no context → Demo Mode with sample patients.
 */
function render(client) {
  ReactDOM.createRoot(document.getElementById('root')).render(
    <React.StrictMode>
      <App client={client} />
    </React.StrictMode>
  );
}

// OpenMRS FHIR2 base, derived from the OWA's own path (…/<ctx>/owa/<app>/…) so it
// works whatever the context path is. fhirclient requires an absolute URL.
function openmrsFhirBase() {
  const ctx = window.location.pathname.split('/owa/')[0] || '/openmrs';
  return window.location.origin + ctx + '/ws/fhir2/R4';
}

FHIR.oauth2
  .ready()
  .then((client) => render(client))
  .catch((err) => {
    // ready() rejects both when there's simply no SMART context and when a real
    // launch failed mid-handshake. If the URL carries OAuth params, a launch WAS
    // attempted, so surface the error rather than silently hiding a bad redirect.
    const params = new URLSearchParams(window.location.search);
    if (params.has('code') || params.has('error')) {
      console.error('[SMART] Launch failed, falling back:', err);
    }

    // Opened from the OpenMRS dashboard widget: no SMART launch, but a patient
    // UUID is in the URL. Talk to OpenMRS FHIR2 directly using the session cookie.
    const patientId = params.get('patientId');
    if (patientId) {
      try {
        render(
          FHIR.client({
            serverUrl: openmrsFhirBase(),
            tokenResponse: { patient: patientId },
          })
        );
        return;
      } catch (e) {
        console.error('[FHIR2] standalone client init failed:', e);
      }
    }

    // No context at all → Demo Mode.
    render(null);
  });
