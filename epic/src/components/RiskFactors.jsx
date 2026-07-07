export default function RiskFactors({ factors }) {
  if (factors.length === 0) {
    return (
      <div className="card">
        <div className="card-header">Metabolic Risk Factors</div>
        <div className="card-body text-sm text-slate-500 italic">
          No MASLD risk factors identified from active conditions or recent labs.
        </div>
      </div>
    );
  }

  return (
    <div className="card">
      <div className="card-header flex items-center justify-between">
        <span>Metabolic Risk Factors (Rule 1)</span>
        <span className="badge bg-orange-100 text-orange-800">{factors.length} identified</span>
      </div>
      <div className="card-body">
        <p className="text-xs text-slate-500 mb-3">
          Patient qualifies for MASLD screening based on the following risk factor(s):
        </p>
        <div className="space-y-2">
          {factors.map((f) => (
            <div
              key={f.key}
              className="flex items-center justify-between px-3 py-2 bg-orange-50 border border-orange-100 rounded-lg"
            >
              <div className="flex items-center gap-2">
                <span>{f.icon}</span>
                <span className="text-sm font-medium text-slate-800">{f.label}</span>
              </div>
              <span className="text-xs text-slate-500">{f.source}</span>
            </div>
          ))}
        </div>
        <p className="text-xs text-slate-400 mt-3">
          Per AASLD/AGA/ADA guidelines: patients with T2DM, BMI ≥25 kg/m², dyslipidemia, or
          hypertension should be screened for MASLD using the FIB-4 index.
        </p>
      </div>
    </div>
  );
}
