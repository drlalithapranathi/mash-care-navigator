import { useState } from 'react';
import { DEMO_PATIENTS } from '../data/demoData';
import { extractPatientInfo } from '../utils/fhirHelpers';
import { assessRiskFactors, isEligibleForScreening } from '../utils/riskAssessment';
import { calculateFIB4, getFIB4Risk } from '../utils/fib4';
import PatientHeader from './PatientHeader';
import AlertBanner from './AlertBanner';
import RiskFactors from './RiskFactors';
import LabPanel from './LabPanel';
import FIB4Result from './FIB4Result';

export default function DemoMode() {
  const [selectedId, setSelectedId] = useState(DEMO_PATIENTS[0].id);

  const demo = DEMO_PATIENTS.find((p) => p.id === selectedId);
  const patientInfo = extractPatientInfo(demo.patient);
  const riskFactors = assessRiskFactors(demo.conditions, demo.labs);
  const fib4Score = calculateFIB4(
    patientInfo.age,
    demo.labs.ast?.value,
    demo.labs.alt?.value,
    demo.labs.platelets?.value
  );
  const fib4Risk = getFIB4Risk(fib4Score);
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
            <span className="badge bg-amber-500 text-white text-xs">DEMO MODE</span>
          </div>
        </div>
      </header>

      {/* Demo patient selector */}
      <div className="bg-amber-50 border-b border-amber-200 px-6 py-3">
        <div className="max-w-4xl mx-auto">
          <p className="text-xs text-amber-800 font-semibold mb-2 uppercase tracking-wide">
            Demo Mode — Select a sample patient (in production, patient is loaded from EHR via SMART launch)
          </p>
          <div className="flex flex-wrap gap-2">
            {DEMO_PATIENTS.map((p) => (
              <button
                key={p.id}
                onClick={() => setSelectedId(p.id)}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium border transition-all ${
                  selectedId === p.id
                    ? 'bg-blue-700 text-white border-blue-700 shadow'
                    : 'bg-white text-slate-700 border-slate-300 hover:border-blue-400'
                }`}
              >
                {p.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Main content */}
      <main className="max-w-4xl mx-auto px-4 py-6 space-y-4">
        <PatientHeader patient={patientInfo} isEligible={isEligible} />
        <AlertBanner
          riskFactors={riskFactors}
          labs={demo.labs}
          fib4={fib4Score}
          fib4Risk={fib4Risk}
          patientAge={patientInfo.age}
        />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <RiskFactors factors={riskFactors} />
          <LabPanel labs={demo.labs} />
        </div>

        {fib4Score !== null && (
          <FIB4Result
            score={fib4Score}
            risk={fib4Risk}
            patient={patientInfo}
            labs={demo.labs}
          />
        )}

        {/* Footer note */}
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
