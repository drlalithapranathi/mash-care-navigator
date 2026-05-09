import React from 'react';
import ReactDOM from 'react-dom/client';
import FHIR from 'fhirclient';
import App from './App';
import './index.css';

/**
 * SMART on FHIR entry point.
 *
 * Launch types supported:
 *  1. EHR Launch   — Cerner or Epic opens launch.html → redirects here with auth code
 *  2. Standalone   — Open index.html directly (no EHR context) → Demo Mode with sample patients
 *
 * FHIR.oauth2.ready() completes the OAuth2 PKCE handshake and returns a configured client.
 * If no SMART context exists, it throws and we fall back to Demo Mode.
 */
FHIR.oauth2
  .ready()
  .then((client) => {
    ReactDOM.createRoot(document.getElementById('root')).render(
      <React.StrictMode>
        <App client={client} />
      </React.StrictMode>
    );
  })
  .catch(() => {
    // No SMART context — render in Demo Mode (standalone testing)
    ReactDOM.createRoot(document.getElementById('root')).render(
      <React.StrictMode>
        <App client={null} />
      </React.StrictMode>
    );
  });
