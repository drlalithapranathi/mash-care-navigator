/**
 * MASLD Risk Factor Assessment — Rule 1
 *
 * Trigger conditions (ANY of the following qualifies patient for screening):
 *  - Type 2 Diabetes (ICD-10: E11.x) AND age ≥ 18
 *  - Hemoglobin A1C ≥ 5.7% (pre-diabetes)
 *  - BMI ≥ 25 kg/m²
 *  - Dyslipidemia (ICD-10: E78.x) + another metabolic risk factor
 *  - Hypertension (ICD-10: I10) + another metabolic risk factor
 *  - Incidental finding of hepatic steatosis on imaging
 */

const ICD10_PATTERNS = {
  t2dm: { prefixes: ['E11'], label: 'Type 2 Diabetes Mellitus', icd10: 'E11.x' },
  prediabetes: { prefixes: ['R73.09', 'R73', 'E11.65'], label: 'Pre-diabetes / Impaired glucose', icd10: 'R73.09' },
  dyslipidemia: { prefixes: ['E78'], label: 'Dyslipidemia', icd10: 'E78.x' },
  hypertension: { prefixes: ['I10', 'I11', 'I12', 'I13'], label: 'Hypertension', icd10: 'I10' },
  obesity: { prefixes: ['E66'], label: 'Obesity', icd10: 'E66.x' },
  nafld: { prefixes: ['K76.0', 'K75.81'], label: 'Hepatic steatosis (incidental finding)', icd10: 'K76.0' },
};

const CONDITION_TEXT_KEYWORDS = {
  t2dm: ['type 2 diabetes', 'type ii diabetes', 't2dm', 'diabetes mellitus type 2'],
  prediabetes: ['pre-diabetes', 'prediabetes', 'impaired fasting', 'impaired glucose'],
  dyslipidemia: ['dyslipidemia', 'hyperlipidemia', 'hypercholesterolemia', 'hypertriglyceridemia'],
  hypertension: ['hypertension', 'high blood pressure'],
  obesity: ['obesity', 'morbid obesity'],
  nafld: ['fatty liver', 'hepatic steatosis', 'steatohepatitis', 'masld', 'nafld', 'nash', 'mash'],
};

function conditionMatchesKey(condition, key) {
  const codings = condition.code?.coding || [];
  const text = (condition.code?.text || '').toLowerCase();

  const patterns = ICD10_PATTERNS[key];
  const keywords = CONDITION_TEXT_KEYWORDS[key];

  const codingMatch = codings.some((c) =>
    patterns.prefixes.some((prefix) => c.code?.startsWith(prefix))
  );
  const textMatch = keywords.some((kw) => text.includes(kw));
  return codingMatch || textMatch;
}

export function assessRiskFactors(conditions, labs) {
  const factors = [];
  const activeConditions = (conditions ?? []).filter(
    (c) => !c.clinicalStatus || c.clinicalStatus?.coding?.some((s) => s.code === 'active')
  );

  // Condition-based factors
  if (activeConditions.some((c) => conditionMatchesKey(c, 't2dm'))) {
    factors.push({ key: 't2dm', label: 'Type 2 Diabetes Mellitus', source: 'ICD-10: E11.x', icon: '🩸' });
  }
  if (activeConditions.some((c) => conditionMatchesKey(c, 'prediabetes'))) {
    factors.push({ key: 'prediabetes', label: 'Pre-diabetes', source: 'ICD-10: R73.09', icon: '🩸' });
  }
  if (activeConditions.some((c) => conditionMatchesKey(c, 'dyslipidemia'))) {
    factors.push({ key: 'dyslipidemia', label: 'Dyslipidemia', source: 'ICD-10: E78.x', icon: '💊' });
  }
  if (activeConditions.some((c) => conditionMatchesKey(c, 'hypertension'))) {
    factors.push({ key: 'hypertension', label: 'Hypertension', source: 'ICD-10: I10', icon: '❤️' });
  }
  if (activeConditions.some((c) => conditionMatchesKey(c, 'obesity'))) {
    factors.push({ key: 'obesity', label: 'Obesity', source: 'ICD-10: E66.x', icon: '⚖️' });
  }
  if (activeConditions.some((c) => conditionMatchesKey(c, 'nafld'))) {
    factors.push({ key: 'nafld', label: 'Hepatic steatosis (incidental finding)', source: 'ICD-10: K76.0', icon: '🫀' });
  }

  // Observation-based factors
  if (labs?.hba1c?.value != null && labs.hba1c.value >= 5.7) {
    if (!factors.find((f) => f.key === 't2dm' || f.key === 'prediabetes')) {
      factors.push({
        key: 'hba1c',
        label: `HbA1c ≥ 5.7% (${labs.hba1c.value}%)`,
        source: 'Lab result',
        icon: '🧪',
      });
    }
  }

  if (labs?.bmi?.value != null && labs.bmi.value >= 25) {
    if (!factors.find((f) => f.key === 'obesity')) {
      factors.push({
        key: 'bmi',
        label: `BMI ≥ 25 kg/m² (${labs.bmi.value.toFixed(1)})`,
        source: 'Vital sign',
        icon: '⚖️',
      });
    }
  }

  return factors;
}

export function isEligibleForScreening(riskFactors) {
  return riskFactors.length > 0;
}

/** Determines if labs are sufficient to calculate FIB-4 */
export function labStatus(labs) {
  const missing = [];
  if (!labs?.ast?.value) missing.push('AST');
  if (!labs?.alt?.value) missing.push('ALT');
  if (!labs?.platelets?.value) missing.push('Platelet count');
  return { complete: missing.length === 0, missing };
}
