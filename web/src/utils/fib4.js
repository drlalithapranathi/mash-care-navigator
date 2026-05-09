/**
 * FIB-4 Index Calculation
 * Formula: (Age [years] × AST [U/L]) / (Platelets [10⁹/L] × √ALT [U/L])
 *
 * Thresholds (AASLD/AGA/ADA guidelines):
 *   < 1.3   → Low risk: continue standard care, rescreen in 2 years
 *   1.3–2.67 → Intermediate risk: order ELF or FibroScan, consider hepatology referral
 *   > 2.67  → High risk: immediate hepatology referral
 */

export function calculateFIB4(age, ast, alt, platelets) {
  if (age == null || ast == null || alt == null || platelets == null) return null;
  if (alt <= 0 || platelets <= 0 || ast <= 0 || age <= 0) return null;
  return (age * ast) / (platelets * Math.sqrt(alt));
}

export function getFIB4Risk(score) {
  if (score === null || score === undefined || isNaN(score)) return null;

  if (score < 1.3) {
    return {
      level: 1,
      category: 'low',
      label: 'Low Risk',
      colorClass: 'green',
      bgClass: 'bg-green-50',
      borderClass: 'border-green-400',
      textClass: 'text-green-800',
      badgeClass: 'bg-green-100 text-green-800',
      iconColor: 'text-green-500',
      alert: 'Patient at low risk for advanced fibrosis. Continue standard care.',
      recommendation: 'Continue standard care. Rescreen in 2 years.',
      actions: ['Rescreen in 2 years', 'Continue routine metabolic management'],
    };
  }

  if (score <= 2.67) {
    return {
      level: 2,
      category: 'intermediate',
      label: 'Intermediate Risk',
      colorClass: 'yellow',
      bgClass: 'bg-amber-50',
      borderClass: 'border-amber-400',
      textClass: 'text-amber-800',
      badgeClass: 'bg-amber-100 text-amber-800',
      iconColor: 'text-amber-500',
      alert:
        'Intermediate fibrosis risk. Consider hepatology referral or additional testing (ELF, FibroScan). Patient may be candidate for resmetirom (Rezdiffra) therapy.',
      recommendation:
        'Order additional testing (blood-based ELF or FibroScan). Consider hepatology referral. Patient may be a candidate for resmetirom (Rezdiffra) therapy pending further hepatology evaluation.',
      actions: [
        'Order Enhanced Liver Fibrosis (ELF) test',
        'Order FibroScan (VCTE)',
        'Consider hepatology referral',
      ],
    };
  }

  return {
    level: 3,
    category: 'high',
    label: 'High Risk',
    colorClass: 'red',
    bgClass: 'bg-red-50',
    borderClass: 'border-red-500',
    textClass: 'text-red-800',
    badgeClass: 'bg-red-100 text-red-800',
    iconColor: 'text-red-500',
    alert:
      'HIGH RISK for advanced fibrosis. HEPATOLOGY REFERRAL RECOMMENDED. (potential cirrhosis requiring screening for hepatocellular cancer or may be a candidate for resmetirom (Rezdiffra) therapy).',
    recommendation:
      'IMMEDIATE hepatology referral recommended. Potential cirrhosis — screen for hepatocellular carcinoma. Patient may be a candidate for resmetirom (Rezdiffra) therapy.',
    actions: [
      'Initiate hepatology referral (URGENT)',
      'Screen for hepatocellular carcinoma',
      'Evaluate for resmetirom (Rezdiffra) candidacy',
    ],
  };
}

/** Returns the FIB-4 score formatted to 2 decimal places */
export function formatFIB4(score) {
  if (score === null || score === undefined) return '—';
  return score.toFixed(2);
}
