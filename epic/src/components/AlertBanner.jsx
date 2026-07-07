import { formatFIB4 } from '../utils/fib4';

const LEVEL_CONFIG = {
  1: { icon: '✅', title: 'LEVEL 1 — Low Risk', headerBg: 'bg-green-700' },
  2: { icon: '⚠️', title: 'LEVEL 2 — Intermediate Risk (Action Recommended)', headerBg: 'bg-amber-600' },
  3: { icon: '🚨', title: 'LEVEL 3 — High Risk (URGENT ACTION REQUIRED)', headerBg: 'bg-red-700' },
};

export default function AlertBanner({ riskFactors, labs, fib4, fib4Risk, patientAge }) {
  const isEligible = riskFactors.length > 0;
  const hasAllLabs = labs?.ast?.value && labs?.alt?.value && labs?.platelets?.value;
  const missingLabs = [];
  if (!labs?.ast?.value) missingLabs.push('AST');
  if (!labs?.alt?.value) missingLabs.push('ALT');
  if (!labs?.platelets?.value) missingLabs.push('Platelet count');

  // Not eligible at all
  if (!isEligible) {
    return (
      <div className="card border-slate-200">
        <div className="card-body flex items-center gap-3 text-slate-600">
          <span className="text-2xl">ℹ️</span>
          <p className="text-sm">
            Patient does not currently meet MASLD screening criteria. No active metabolic risk factors
            identified.
          </p>
        </div>
      </div>
    );
  }

  // Eligible, labs present, but patient age unavailable — can't calculate FIB-4
  if (hasAllLabs && patientAge == null) {
    return (
      <div className="card border-l-4 border-amber-400">
        <div className="bg-amber-600 text-white px-5 py-2.5 rounded-t-xl flex items-center gap-2">
          <span className="text-lg">⚠️</span>
          <span className="font-semibold text-sm">PATIENT DATE OF BIRTH REQUIRED</span>
        </div>
        <div className="card-body space-y-2">
          <p className="text-slate-700 font-medium">
            Patient meets MASLD screening criteria and required labs are available, but FIB-4 cannot
            be calculated — <strong>date of birth is missing or unreadable in the EHR record</strong>.
          </p>
          <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 text-sm text-amber-900">
            FIB-4 formula requires patient age (years). Please verify and update the patient's date
            of birth in the EHR.
          </div>
        </div>
      </div>
    );
  }

  // Eligible but labs missing
  if (!hasAllLabs) {
    return (
      <div className="card border-l-4 border-amber-400">
        <div className="bg-amber-600 text-white px-5 py-2.5 rounded-t-xl flex items-center gap-2">
          <span className="text-lg">⚠️</span>
          <span className="font-semibold text-sm">LABS REQUIRED FOR FIB-4 SCREENING</span>
        </div>
        <div className="card-body space-y-3">
          <p className="text-slate-700 font-medium">
            Patient meets MASLD screening criteria. Complete labs required for FIB-4 calculation.
          </p>
          <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 text-sm text-amber-900">
            <p className="font-semibold mb-1">
              Consider ordering: {missingLabs.join(', ')} for MASLD screening.
            </p>
            <p className="text-amber-700">
              Order sets: Complete Blood Count (CBC) and Hepatic Function Panel (HFP)
            </p>
          </div>
          <ul className="text-sm text-slate-600 space-y-1">
            {missingLabs.map((lab) => (
              <li key={lab} className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-amber-400 inline-block" />
                <strong>{lab}</strong> — not available within last 12 months
              </li>
            ))}
          </ul>
        </div>
      </div>
    );
  }

  // FIB-4 calculated — show risk-level alert
  if (!fib4Risk) return null;
  const cfg = LEVEL_CONFIG[fib4Risk.level];

  return (
    <div className={`card border-l-4 ${fib4Risk.borderClass}`}>
      <div className={`${cfg.headerBg} text-white px-5 py-2.5 rounded-t-xl flex items-center gap-2`}>
        <span className="text-lg">{cfg.icon}</span>
        <span className="font-bold text-sm tracking-wide">{cfg.title}</span>
        <span className="ml-auto text-white/90 font-mono font-bold text-lg">
          FIB-4: {formatFIB4(fib4)}
        </span>
      </div>

      <div className="card-body space-y-4">
        {/* Alert message */}
        <div className={`${fib4Risk.bgClass} border ${fib4Risk.borderClass} rounded-lg p-4`}>
          <p className={`text-sm font-semibold ${fib4Risk.textClass} leading-relaxed`}>
            {fib4Risk.alert}
          </p>
        </div>

        {/* FIB-4 visual gauge */}
        <FIB4Gauge score={fib4} />

        {/* Recommended actions */}
        <div>
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500 mb-2">
            Recommended Actions
          </p>
          <div className="space-y-2">
            {fib4Risk.actions.map((action, i) => (
              <div
                key={i}
                className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm ${
                  i === 0 && fib4Risk.level === 3
                    ? 'bg-red-50 border border-red-200 font-semibold text-red-800'
                    : 'bg-slate-50 border border-slate-200 text-slate-700'
                }`}
              >
                <span>{i === 0 && fib4Risk.level === 3 ? '🚨' : '→'}</span>
                {action}
              </div>
            ))}
          </div>
        </div>

        {/* Drug note for level 2 and 3 */}
        {fib4Risk.level >= 2 && (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 text-xs text-blue-800">
            <strong>Note:</strong> Resmetirom (Rezdiffra) — first FDA-approved pharmacotherapy for
            non-cirrhotic MASH with stage 2–3 hepatic fibrosis (approved March 2024). Hepatology
            evaluation required to confirm candidacy.
          </div>
        )}
      </div>
    </div>
  );
}

function FIB4Gauge({ score }) {
  // Scale: 0 to 4+ mapped to 0–100%
  const max = 4.5;
  const pct = Math.min((score / max) * 100, 100);
  const low = (1.3 / max) * 100;
  const high = (2.67 / max) * 100;

  return (
    <div>
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500 mb-2">FIB-4 Score</p>
      <div className="relative h-5 rounded-full overflow-hidden flex">
        <div className="bg-green-400" style={{ width: `${low}%` }} />
        <div className="bg-amber-400" style={{ width: `${high - low}%` }} />
        <div className="bg-red-500 flex-1" />
        {/* Needle */}
        <div
          className="absolute top-0 bottom-0 w-1 bg-slate-900 rounded-full shadow-lg"
          style={{ left: `calc(${pct}% - 2px)` }}
        />
      </div>
      <div className="flex justify-between text-xs text-slate-500 mt-1">
        <span>0</span>
        <span className="text-green-700 font-medium">Low &lt;1.3</span>
        <span className="text-amber-700 font-medium">1.3 ─ 2.67</span>
        <span className="text-red-700 font-medium">High &gt;2.67</span>
        <span>{max}+</span>
      </div>
    </div>
  );
}
