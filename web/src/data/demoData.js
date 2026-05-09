/**
 * Demo patients for standalone mode testing.
 * Covers all 4 clinical scenarios from the proposal.
 */

export const DEMO_PATIENTS = [
  {
    id: 'demo-1',
    label: 'HIGH RISK — FIB-4 > 2.67',
    patient: {
      resourceType: 'Patient',
      id: 'demo-1',
      name: [{ given: ['John'], family: 'Smith' }],
      birthDate: '1960-03-15',
      gender: 'male',
      identifier: [{ system: 'urn:mrn', value: 'MRN-100234' }],
    },
    conditions: [
      fakeCondition('E11.9', 'Type 2 diabetes mellitus without complications'),
      fakeCondition('E78.5', 'Hyperlipidemia, unspecified'),
      fakeCondition('I10', 'Essential (primary) hypertension'),
    ],
    labs: {
      ast: { value: 58, unit: 'U/L', date: recentDate(10) },
      alt: { value: 44, unit: 'U/L', date: recentDate(10) },
      platelets: { value: 142, unit: 'K/uL', date: recentDate(10) },
      hba1c: { value: 7.8, unit: '%', date: recentDate(30) },
      bmi: { value: 33.2, unit: 'kg/m2', date: recentDate(5) },
    },
    // FIB-4 = (65 × 58) / (142 × √44) = 3770 / 941.9 ≈ 4.00
  },
  {
    id: 'demo-2',
    label: 'INTERMEDIATE RISK — FIB-4 1.3–2.67',
    patient: {
      resourceType: 'Patient',
      id: 'demo-2',
      name: [{ given: ['Jane'], family: 'Doe' }],
      birthDate: '1970-07-22',
      gender: 'female',
      identifier: [{ system: 'urn:mrn', value: 'MRN-200456' }],
    },
    conditions: [
      fakeCondition('E11.65', 'Type 2 diabetes mellitus with hyperglycemia'),
      fakeCondition('E66.01', 'Morbid (severe) obesity due to excess calories'),
    ],
    labs: {
      ast: { value: 46, unit: 'U/L', date: recentDate(15) },
      alt: { value: 52, unit: 'U/L', date: recentDate(15) },
      platelets: { value: 185, unit: 'K/uL', date: recentDate(15) },
      hba1c: { value: 6.4, unit: '%', date: recentDate(45) },
      bmi: { value: 38.5, unit: 'kg/m2', date: recentDate(3) },
    },
    // FIB-4 = (55 × 46) / (185 × √52) = 2530 / 1334 ≈ 1.90
  },
  {
    id: 'demo-3',
    label: 'LOW RISK — FIB-4 < 1.3',
    patient: {
      resourceType: 'Patient',
      id: 'demo-3',
      name: [{ given: ['Robert'], family: 'Johnson' }],
      birthDate: '1980-11-05',
      gender: 'male',
      identifier: [{ system: 'urn:mrn', value: 'MRN-300789' }],
    },
    conditions: [
      fakeCondition('E78.00', 'Pure hypercholesterolemia, unspecified'),
      fakeCondition('I10', 'Essential (primary) hypertension'),
    ],
    labs: {
      ast: { value: 28, unit: 'U/L', date: recentDate(20) },
      alt: { value: 32, unit: 'U/L', date: recentDate(20) },
      platelets: { value: 245, unit: 'K/uL', date: recentDate(20) },
      hba1c: { value: 5.5, unit: '%', date: recentDate(60) },
      bmi: { value: 27.4, unit: 'kg/m2', date: recentDate(7) },
    },
    // FIB-4 = (45 × 28) / (245 × √32) = 1260 / 1385.9 ≈ 0.91
  },
  {
    id: 'demo-4',
    label: 'MISSING LABS — Order Required',
    patient: {
      resourceType: 'Patient',
      id: 'demo-4',
      name: [{ given: ['Maria'], family: 'Garcia' }],
      birthDate: '1975-05-18',
      gender: 'female',
      identifier: [{ system: 'urn:mrn', value: 'MRN-400012' }],
    },
    conditions: [
      fakeCondition('E11.9', 'Type 2 diabetes mellitus without complications'),
      fakeCondition('E78.5', 'Hyperlipidemia, unspecified'),
    ],
    labs: {
      ast: null,
      alt: null,
      platelets: null,
      hba1c: { value: 8.1, unit: '%', date: recentDate(20) },
      bmi: { value: 31.0, unit: 'kg/m2', date: recentDate(4) },
    },
  },
];

function fakeCondition(code, display) {
  return {
    resourceType: 'Condition',
    clinicalStatus: {
      coding: [{ system: 'http://terminology.hl7.org/CodeSystem/condition-clinical', code: 'active' }],
    },
    code: {
      coding: [{ system: 'http://hl7.org/fhir/sid/icd-10-cm', code, display }],
      text: display,
    },
  };
}

function recentDate(daysAgo) {
  const d = new Date();
  d.setDate(d.getDate() - daysAgo);
  return d.toISOString().split('T')[0];
}
