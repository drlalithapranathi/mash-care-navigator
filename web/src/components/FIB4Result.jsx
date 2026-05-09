import { formatFIB4 } from '../utils/fib4';

export default function FIB4Result({ score, risk, patient, labs }) {
  if (score === null || !risk) return null;

  const { age } = patient;
  const ast = labs?.ast?.value;
  const alt = labs?.alt?.value;
  const platelets = labs?.platelets?.value;

  const numerator = age * ast;
  const sqrtAlt = Math.sqrt(alt);
  const denominator = platelets * sqrtAlt;

  return (
    <div className="card">
      <div className="card-header flex items-center justify-between">
        <span>FIB-4 Calculation (Rule 3)</span>
        <span className={`badge ${risk.badgeClass} text-xs font-semibold`}>{risk.label}</span>
      </div>
      <div className="card-body space-y-4">
        {/* Formula display */}
        <div className="bg-slate-50 border border-slate-200 rounded-lg p-4 font-mono text-sm">
          <p className="text-slate-500 text-xs mb-3 font-sans not-italic">
            FIB-4 Index Formula (AASLD/AGA/ADA Guidelines)
          </p>
          <div className="space-y-1 text-slate-700">
            <p>
              FIB-4 = <span className="text-blue-700">(Age × AST)</span> /{' '}
              <span className="text-purple-700">(Platelets × √ALT)</span>
            </p>
            <p className="text-slate-400">{'       '}═══════════════════════════════════</p>
            <p>
              {'       '}={' '}
              <span className="text-blue-700">
                ({age} yrs × {ast} U/L)
              </span>{' '}
              /{' '}
              <span className="text-purple-700">
                ({platelets} K/µL × √{alt} U/L)
              </span>
            </p>
            <p>
              {'       '}={' '}
              <span className="text-blue-700">{numerator.toFixed(0)}</span> /{' '}
              <span className="text-purple-700">
                ({platelets} × {sqrtAlt.toFixed(3)})
              </span>
            </p>
            <p>
              {'       '}={' '}
              <span className="text-blue-700">{numerator.toFixed(0)}</span> /{' '}
              <span className="text-purple-700">{denominator.toFixed(2)}</span>
            </p>
            <p className="text-lg font-bold text-slate-900 mt-2">
              {'       '}={' '}
              <span className={risk.textClass}>{formatFIB4(score)}</span>
            </p>
          </div>
        </div>

        {/* Threshold reference */}
        <div className="grid grid-cols-3 gap-3 text-center text-sm">
          <ThresholdCard
            range="< 1.3"
            label="Low Risk"
            action="Continue standard care. Rescreen in 2 years."
            active={risk.category === 'low'}
            colorClass="green"
          />
          <ThresholdCard
            range="1.3 – 2.67"
            label="Intermediate Risk"
            action="Order ELF or FibroScan. Consider hepatology referral."
            active={risk.category === 'intermediate'}
            colorClass="amber"
          />
          <ThresholdCard
            range="> 2.67"
            label="High Risk"
            action="IMMEDIATE hepatology referral. Screen for HCC."
            active={risk.category === 'high'}
            colorClass="red"
          />
        </div>
      </div>
    </div>
  );
}

function ThresholdCard({ range, label, action, active, colorClass }) {
  const colors = {
    green: {
      border: active ? 'border-green-500 shadow-green-100' : 'border-slate-200',
      bg: active ? 'bg-green-50' : 'bg-white',
      label: active ? 'text-green-800' : 'text-slate-600',
      range: active ? 'text-green-700' : 'text-slate-500',
    },
    amber: {
      border: active ? 'border-amber-500 shadow-amber-100' : 'border-slate-200',
      bg: active ? 'bg-amber-50' : 'bg-white',
      label: active ? 'text-amber-800' : 'text-slate-600',
      range: active ? 'text-amber-700' : 'text-slate-500',
    },
    red: {
      border: active ? 'border-red-500 shadow-red-100' : 'border-slate-200',
      bg: active ? 'bg-red-50' : 'bg-white',
      label: active ? 'text-red-800' : 'text-slate-600',
      range: active ? 'text-red-700' : 'text-slate-500',
    },
  };

  const c = colors[colorClass];

  return (
    <div
      className={`border-2 rounded-xl p-3 ${c.border} ${c.bg} ${active ? 'shadow-md' : ''} transition-all`}
    >
      {active && <div className="text-xs font-bold mb-1">▶ CURRENT</div>}
      <p className={`text-base font-bold font-mono ${c.range}`}>{range}</p>
      <p className={`text-xs font-semibold mt-1 ${c.label}`}>{label}</p>
      <p className="text-xs text-slate-500 mt-1 leading-tight">{action}</p>
    </div>
  );
}
