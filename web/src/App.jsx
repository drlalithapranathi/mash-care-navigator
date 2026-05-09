import { useState, useEffect } from 'react';
import { fetchPatientData, extractPatientInfo } from './utils/fhirHelpers';
import { assessRiskFactors, isEligibleForScreening } from './utils/riskAssessment';
import { calculateFIB4, getFIB4Risk } from './utils/fib4';
import PatientHeader from './components/PatientHeader';
import AlertBanner from './components/AlertBanner';
import RiskFactors from './components/RiskFactors';
import LabPanel from './components/LabPanel';
import FIB4Result from './components/FIB4Result';
import LoadingSpinner from './components/LoadingSpinner';
import DemoMode from './components/DemoMode';

export default function App({ client }) {
  const [state, setState] = useState({ status: 'loading', error: null, data: null });

  useEffect(() => {
    if (!client) {
      setState({ status: 'demo', error: null, data: null });
      return;
    }

    fetchPatientData(client)
      .then(({ patient, conditions, labs }) => {
        const patientInfo = extractPatientInfo(patient);
        const riskFactors = assessRiskFactors(conditions, labs);
        const fib4Score = calculateFIB4(
          patientInfo.age,
          labs.ast?.value,
          labs.alt?.value,
          labs.platelets?.value
        );
        const fib4Risk = getFIB4Risk(fib4Score);

        setState({
          status: 'ready',
          error: null,
          data: { patientInfo, conditions, labs, riskFactors, fib4Score, fib4Risk },
        });
      })
      .catch((err) => {
        console.error('FHIR data fetch error:', err);
        setState({ status: 'error', error: err.message, data: null });
      });
  }, [client]);

  if (state.status === 'loading') return <LoadingSpinner />;
  if (state.status === 'demo') return <DemoMode />;

  if (state.status === 'error') {
    return (
      <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
        <div className="card max-w-md w-full p-6 text-center">
          <div className="text-4xl mb-3">⚠️</div>
          <h2 className="text-lg font-bold text-slate-800 mb-2">Unable to Load Patient Data</h2>
          <p className="text-sm text-slate-600 mb-4">{state.error}</p>
          <button onClick={() => window.location.reload()} className="btn-primary">
            Retry
          </button>
        </div>
      </div>
    );
  }

  const { patientInfo, labs, riskFactors, fib4Score, fib4Risk } = state.data;
  const isEligible = isEligibleForScreening(riskFactors);

  return (
    <div className="min-h-screen bg-slate-50">
      {/* App header */}
      <header className="bg-blue-900 text-white px-6 py-4 shadow-lg">
        <div className="max-w-4xl mx-auto flex items-center justify-between">
          <div>
            <h1 className="text-xl font-bold tracking-tight">MASH Care Navigator</h1>
            <p className="text-blue-300 text-xs mt-0.5">
              MASLD Screening &amp; Referral Decision Support · SMART on FHIR R4
            </p>
          </div>
          <div className="flex items-center gap-2">
            <span className="badge bg-green-500 text-white text-xs">● LIVE</span>
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="max-w-4xl mx-auto px-4 py-6 space-y-4">
        <PatientHeader patient={patientInfo} isEligible={isEligible} />

        <AlertBanner
          riskFactors={riskFactors}
          labs={labs}
          fib4={fib4Score}
          fib4Risk={fib4Risk}
          patientAge={patientInfo.age}
        />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <RiskFactors factors={riskFactors} />
          <LabPanel labs={labs} />
        </div>

        {fib4Score !== null && (
          <FIB4Result score={fib4Score} risk={fib4Risk} patient={patientInfo} labs={labs} />
        )}

        <div className="text-center text-xs text-slate-400 pt-2 pb-6">
          MASH Care Navigator · SMART on FHIR R4 · Client ID: e1059be6-b584-4400-8111-d413ec15f7a9
          <br />
          Clinical Champion: Dr. Niharika Samala, MD · Developer: Lalitha Pranathi Pulavarthy, BDS ·
          Advisor: Dr. Saptarshi Purkayastha, PhD
        </div>
      </main>
    </div>
  );
}
