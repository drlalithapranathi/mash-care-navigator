/**
 * FHIR R4 Data Helpers
 * Supports both EHR-launch (Epic/Cerner) and Standalone launch contexts.
 */

// LOINC codes for required labs
const LOINC = {
  AST: ['1920-8', '30239-8'],
  ALT: ['1742-6', '76625-3'],
  PLATELETS: ['777-3', '26515-7', '74775-7'],
  HBA1C: ['4548-4', '17855-8', '59261-8'],
  BMI: ['39156-5'],
};

/** Build date cutoff string (n months ago) */
function monthsAgo(n) {
  const d = new Date();
  d.setMonth(d.getMonth() - n);
  return d.toISOString().split('T')[0];
}

/** Extract numeric value from an Observation resource.
 *  Handles: valueQuantity, valueString, valueInteger, valueDecimal.
 *  Safely skips non-numeric types (valueCodeableConcept, valueSampledData, etc.)
 */
function extractValue(obs) {
  if (!obs) return null;
  const entry = obs.entry?.[0]?.resource ?? (obs.resourceType === 'Observation' ? obs : null);
  if (!entry) return null;

  let rawValue = null;
  let unit = '';

  if (entry.valueQuantity != null) {
    // Most common: { value: 58, unit: "U/L" }
    rawValue = entry.valueQuantity.value;
    unit = entry.valueQuantity.unit ?? entry.valueQuantity.code ?? '';
  } else if (entry.valueString != null) {
    // Some Cerner instances return e.g. "7.8" as a string
    rawValue = entry.valueString;
  } else if (entry.valueDecimal != null) {
    rawValue = entry.valueDecimal;
  } else if (entry.valueInteger != null) {
    rawValue = entry.valueInteger;
  } else {
    // valueCodeableConcept, valueSampledData, etc. — not usable as a number
    return null;
  }

  const numeric = parseFloat(rawValue);
  if (isNaN(numeric)) return null;

  const date =
    entry.effectiveDateTime ??
    entry.effectivePeriod?.start ??
    entry.issued ??
    null;

  // Normalise platelets: K/uL (10³/µL) is numerically identical to 10⁹/L for FIB-4
  return { value: numeric, unit, date };
}

/** Fetch the most recent observation for given LOINC codes within cutoff months.
 *  Tries a fully-featured query first, then degrades gracefully for servers with
 *  limited search capability (e.g. no _sort, no comma-separated status).
 */
async function fetchLatestObs(client, loincs, cutoffMonths = 12) {
  const code = loincs.map((c) => `http://loinc.org|${c}`).join(',');
  const since = monthsAgo(cutoffMonths);

  // Attempt 1: full query with sort + date filter + status (most FHIR R4 servers)
  try {
    const result = await client.patient.request(
      `Observation?code=${code}&date=ge${since}&_sort=-date&_count=1&status=final&status=amended&status=corrected`
    );
    const val = extractValue(result);
    if (val !== null) return val;
  } catch {
    // fall through
  }

  // Attempt 2: drop status filter (some servers don't support multiple status params)
  try {
    const result = await client.patient.request(
      `Observation?code=${code}&date=ge${since}&_sort=-date&_count=1`
    );
    const val = extractValue(result);
    if (val !== null) return val;
  } catch {
    // fall through
  }

  // Attempt 3: drop date filter and sort, just get latest by any date, take first result
  try {
    const result = await client.patient.request(
      `Observation?code=${code}&_count=5`
    );
    // Find most recent manually if multiple returned
    const entries = result.entry ?? [];
    const sorted = entries
      .map((e) => e.resource)
      .filter(Boolean)
      .sort((a, b) => {
        const da = new Date(a.effectiveDateTime ?? a.issued ?? 0);
        const db = new Date(b.effectiveDateTime ?? b.issued ?? 0);
        return db - da;
      });
    for (const resource of sorted) {
      const val = extractValue({ resourceType: 'Observation', ...resource });
      if (val !== null) return val;
    }
  } catch {
    // fall through
  }

  return null;
}

/** Extract structured patient info */
export function extractPatientInfo(patient) {
  const name = patient.name?.[0];
  const given = name?.given?.join(' ') ?? '';
  const family = name?.family ?? '';
  const fullName = `${given} ${family}`.trim() || 'Unknown Patient';

  const dob = patient.birthDate ?? null;
  const age = dob ? calculateAge(dob) : null;

  const gender = patient.gender
    ? patient.gender.charAt(0).toUpperCase() + patient.gender.slice(1)
    : 'Unknown';

  const mrn =
    patient.identifier?.find(
      (id) =>
        id.type?.coding?.some(
          (c) => c.code === 'MR' || c.system?.includes('v2-0203')
        ) || id.system?.toLowerCase().includes('mrn')
    )?.value ?? patient.id;

  return { fullName, dob, age, gender, mrn };
}

function calculateAge(birthDateStr) {
  if (!birthDateStr) return null;
  const dob = new Date(birthDateStr);
  if (isNaN(dob.getTime())) return null; // malformed date string
  const today = new Date();
  let age = today.getFullYear() - dob.getFullYear();
  const m = today.getMonth() - dob.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) age--;
  return age >= 0 ? age : null;
}

/** Fetch all FHIR data needed for MASLD screening */
export async function fetchPatientData(client) {
  // Patient demographics
  const patient = await client.patient.read();

  // Active conditions (for risk factor identification)
  let conditions = [];
  try {
    const condBundle = await client.patient.request(
      `Condition?clinical-status=active&_count=200`
    );
    conditions = condBundle.entry?.map((e) => e.resource) ?? [];
  } catch {
    // Some servers may not support all params; try without filter
    try {
      const fallback = await client.patient.request(`Condition?_count=200`);
      conditions = fallback.entry?.map((e) => e.resource) ?? [];
    } catch {
      conditions = [];
    }
  }

  // Fetch all required labs in parallel
  const [ast, alt, platelets, hba1c, bmi] = await Promise.all([
    fetchLatestObs(client, LOINC.AST),
    fetchLatestObs(client, LOINC.ALT),
    fetchLatestObs(client, LOINC.PLATELETS),
    fetchLatestObs(client, LOINC.HBA1C, 12),
    fetchLatestObs(client, LOINC.BMI, 12),
  ]);

  return {
    patient,
    conditions,
    labs: { ast, alt, platelets, hba1c, bmi },
  };
}

/** Format a FHIR date string as MM/DD/YYYY */
export function formatDate(dateStr) {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('en-US', { month: '2-digit', day: '2-digit', year: 'numeric' });
}

/** Format a DOB string as MM/DD/YYYY */
export function formatDOB(dobStr) {
  return formatDate(dobStr);
}
