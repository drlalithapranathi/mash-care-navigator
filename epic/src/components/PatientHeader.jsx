import { formatDOB } from '../utils/fhirHelpers';

export default function PatientHeader({ patient, isEligible }) {
  const { fullName, dob, age, gender, mrn } = patient;

  return (
    <div className="card">
      <div className="flex items-start justify-between px-5 py-4">
        <div>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-bold text-lg">
              {fullName.charAt(0)}
            </div>
            <div>
              <h2 className="text-xl font-bold text-slate-900">{fullName}</h2>
              <div className="flex flex-wrap gap-x-4 gap-y-0.5 text-sm text-slate-500 mt-0.5">
                <span>DOB: <strong className="text-slate-700">{dob ? formatDOB(dob) : <span className="text-red-500">Not on record</span>}</strong></span>
                <span>Age: <strong className="text-slate-700">{age != null ? `${age} yrs` : <span className="text-red-500">Unknown</span>}</strong></span>
                <span>Sex: <strong className="text-slate-700">{gender}</strong></span>
                {mrn && <span>MRN: <strong className="text-slate-700">{mrn}</strong></span>}
              </div>
            </div>
          </div>
        </div>

        <div className="flex-shrink-0">
          {isEligible ? (
            <span className="badge bg-orange-100 text-orange-800 text-xs">
              ⚠ Meets MASLD Screening Criteria
            </span>
          ) : (
            <span className="badge bg-slate-100 text-slate-600 text-xs">
              No MASLD risk factors identified
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
