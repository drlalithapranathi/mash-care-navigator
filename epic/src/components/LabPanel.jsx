import { formatDate } from '../utils/fhirHelpers';

const LAB_DEFS = [
  { key: 'ast', label: 'AST', fullName: 'Aspartate Aminotransferase', unit: 'U/L', required: true, loinc: '1920-8' },
  { key: 'alt', label: 'ALT', fullName: 'Alanine Aminotransferase', unit: 'U/L', required: true, loinc: '1742-6' },
  {
    key: 'platelets',
    label: 'Platelets',
    fullName: 'Platelet Count',
    unit: 'K/µL',
    required: true,
    loinc: '777-3',
  },
  {
    key: 'hba1c',
    label: 'HbA1c',
    fullName: 'Hemoglobin A1c',
    unit: '%',
    required: false,
    loinc: '4548-4',
    flagThreshold: 5.7,
    flagLabel: '≥5.7% = Pre-diabetes',
  },
  {
    key: 'bmi',
    label: 'BMI',
    fullName: 'Body Mass Index',
    unit: 'kg/m²',
    required: false,
    loinc: '39156-5',
    flagThreshold: 25,
    flagLabel: '≥25 = Overweight/Obese',
  },
];

export default function LabPanel({ labs }) {
  return (
    <div className="card">
      <div className="card-header flex items-center justify-between">
        <span>Laboratory Results (Rule 2)</span>
        <span className="text-xs text-slate-400 font-normal normal-case tracking-normal">
          Within 12 months
        </span>
      </div>
      <div className="card-body p-0">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-slate-100 text-xs text-slate-500 uppercase tracking-wide">
              <th className="text-left px-5 py-2 font-medium">Test</th>
              <th className="text-right px-5 py-2 font-medium">Result</th>
              <th className="text-right px-5 py-2 font-medium">Date</th>
              <th className="text-center px-5 py-2 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {LAB_DEFS.map((def, i) => {
              const lab = labs?.[def.key];
              const available = lab?.value != null;
              const flagged =
                available && def.flagThreshold != null && lab.value >= def.flagThreshold;

              return (
                <tr
                  key={def.key}
                  className={`${i % 2 === 0 ? 'bg-white' : 'bg-slate-50'} border-b border-slate-50 last:border-0`}
                >
                  <td className="px-5 py-3">
                    <div className="flex items-center gap-2">
                      <div>
                        <span className="font-semibold text-slate-800">{def.label}</span>
                        {def.required && (
                          <span className="ml-1 text-xs text-red-500 font-normal">*</span>
                        )}
                        <p className="text-xs text-slate-400">{def.fullName}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-5 py-3 text-right">
                    {available ? (
                      <span
                        className={`font-mono font-semibold ${
                          flagged ? 'text-amber-700' : 'text-slate-800'
                        }`}
                      >
                        {def.key === 'bmi' ? lab.value.toFixed(1) : lab.value} {lab.unit || def.unit}
                        {flagged && (
                          <span className="ml-1 text-xs text-amber-600">↑</span>
                        )}
                      </span>
                    ) : (
                      <span className="text-slate-400 italic text-xs">Not available</span>
                    )}
                  </td>
                  <td className="px-5 py-3 text-right text-xs text-slate-500">
                    {available ? formatDate(lab.date) : '—'}
                  </td>
                  <td className="px-5 py-3 text-center">
                    {available ? (
                      <span className="badge bg-green-100 text-green-700">✓ Available</span>
                    ) : def.required ? (
                      <span className="badge bg-red-100 text-red-700">⚠ Missing</span>
                    ) : (
                      <span className="badge bg-slate-100 text-slate-500">— N/A</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        <div className="px-5 py-2 text-xs text-slate-400 border-t border-slate-100">
          * Required for FIB-4 calculation · LOINC codes: AST 1920-8, ALT 1742-6, Platelets 777-3
        </div>
      </div>
    </div>
  );
}
