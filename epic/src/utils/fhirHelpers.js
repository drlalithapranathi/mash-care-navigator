/**
 * FHIR R4 Data Helpers
 * Supports both EHR-launch (Epic/Cerner) and Standalone launch contexts.
 */

// Codes for required labs. `loinc` is used by Epic/Cerner; `openmrs` are this
// deployment's concept UUIDs — OpenMRS FHIR2 exposes obs under the concept's own
// (system-less) code rather than a LOINC coding, so we query by UUID too.
const LABS = {
  AST:       { loinc: ['1920-8', '30239-8'],            openmrs: ['5914052f-e777-4efc-949b-0dee321ae55f'] },
  ALT:       { loinc: ['1742-6', '76625-3'],            openmrs: ['29a09214-cfd4-4db9-898e-f2a3e6f08feb'] },
  PLATELETS: { loinc: ['777-3', '26515-7', '74775-7'],  openmrs: ['8575950e-90bf-4530-9595-deebbdf2cdde'] },
  HBA1C:     { loinc: ['4548-4', '17855-8', '59261-8'], openmrs: ['b1c56e95-075a-47f3-8712-100c4d9efe1d'] },
  BMI:       { loinc: ['39156-5'],                      openmrs: ['4448c907-7fed-416c-9871-541b6c3b72b1'] },
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

/** Effective timestamp of an Observation, for client-side "latest" selection. */
function obsDate(o) {
  return new Date(
    o.effectiveDateTime ?? o.effectivePeriod?.start ?? o.issued ?? 0
  ).getTime();
}

/** From a search bundle, pick the newest observation that yields a numeric value.
 *  We always sort client-side: Epic (and some others) ignore `_sort=-date`, so
 *  bundle order can't be trusted to be newest-first.
 */
function pickLatest(bundle) {
  const resources = (bundle?.entry ?? [])
    .map((e) => e.resource)
    .filter((r) => r && r.resourceType === 'Observation')
    .sort((a, b) => obsDate(b) - obsDate(a));
  for (const r of resources) {
    const val = extractValue(r);
    if (val !== null) return val;
  }
  return null;
}

/** Fetch the most recent observation for given LOINC codes within cutoff months.
 *  Tries a fully-featured query first, then degrades gracefully for servers with
 *  limited search capability. Notes on the query shape:
 *   - `status=final,amended,corrected` is a comma OR-list; repeated `status=`
 *     params are AND in FHIR search and would match nothing.
 *   - `category` (laboratory / vital-signs) is required or strongly preferred by
 *     several EHRs (Epic) to return Observation results.
 *   - Never rely on `_sort=-date`; fetch a window and sort client-side.
 */
async function fetchLatestObs(client, codes, category, cutoffMonths = 12) {
  const loincCode = (codes.loinc || []).map((c) => `http://loinc.org|${c}`).join(',');
  const uuidCode = (codes.openmrs || []).join(',');
  const since = monthsAgo(cutoffMonths);
  const cat = category ? `&category=${category}` : '';

  const queries = [];
  // Epic/Cerner: LOINC-coded. Full → drop status → drop category+date.
  if (loincCode) {
    queries.push(
      `Observation?code=${loincCode}${cat}&date=ge${since}&status=final,amended,corrected&_count=100`,
      `Observation?code=${loincCode}${cat}&date=ge${since}&_count=100`,
      `Observation?code=${loincCode}&_count=100`
    );
  }
  // OpenMRS FHIR2: obs carry the concept's own (system-less) code, not LOINC, and
  // a mixed LOINC-or-UUID OR-list matches nothing — so query the UUIDs on their own.
  if (uuidCode) {
    queries.push(
      `Observation?code=${uuidCode}${cat}&_count=100`,
      `Observation?code=${uuidCode}&_count=100`
    );
  }

  for (const q of queries) {
    try {
      const result = await client.patient.request(q);
      const val = pickLatest(result);
      if (val !== null) return val;
    } catch {
      // try the next, more permissive query
    }
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

  // Active conditions (for risk factor identification).
  // pageLimit:0 follows every Bundle `next` link (Epic pages results, and a
  // risk-factor condition can fall past page 1); flat:true returns the
  // resources already unwrapped from bundle entries.
  let conditions = [];
  try {
    conditions =
      (await client.patient.request(`Condition?clinical-status=active&_count=100`, {
        pageLimit: 0,
        flat: true,
      })) ?? [];
  } catch {
    // Some servers may not support all params; try without filter
    try {
      conditions =
        (await client.patient.request(`Condition?_count=100`, {
          pageLimit: 0,
          flat: true,
        })) ?? [];
    } catch {
      conditions = [];
    }
  }

  // Fetch all required labs in parallel. Category steers the Observation search:
  // liver labs + HbA1c are `laboratory`; BMI is `vital-signs`.
  const [ast, alt, platelets, hba1c, bmi] = await Promise.all([
    fetchLatestObs(client, LABS.AST, 'laboratory'),
    fetchLatestObs(client, LABS.ALT, 'laboratory'),
    fetchLatestObs(client, LABS.PLATELETS, 'laboratory'),
    fetchLatestObs(client, LABS.HBA1C, 'laboratory', 12),
    fetchLatestObs(client, LABS.BMI, 'vital-signs', 12),
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
