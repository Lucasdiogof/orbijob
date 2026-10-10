import type { SalaryPeriod } from './types';

/**
 * Plausibility of a published salary. The aim is to catch figures that are almost certainly a unit or typing error
 * (a yearly salary of "168", an hourly rate of "90000") without second-guessing real ones. A suspicious figure is never
 * corrected (168 is NOT assumed to be 168,000): the pair is held back until the source confirms it.
 * Bounds are in units of the stated currency and are deliberately wide; the same table is mirrored in the Flutter app
 * (app/lib/core/format/salary_check.dart).
 */
const BOUNDS: Record<SalaryPeriod, { min: number; max: number }> = {
  hour: { min: 1, max: 10_000 },
  day: { min: 5, max: 100_000 },
  week: { min: 20, max: 500_000 },
  month: { min: 100, max: 5_000_000 },
  year: { min: 1_000, max: 1_000_000_000 },
};
/** A range whose top is more than this many times its bottom reads like a typo ("1,000-250,000"), not a pay band. */
const MAX_SPREAD = 20;

export type SalaryAssessment = 'plausible' | 'suspicious' | 'inconsistent';

export function assessSalary(min: number | null, max: number | null, period: SalaryPeriod): SalaryAssessment {
  if (min !== null && max !== null && min > max) return 'inconsistent';
  const b = BOUNDS[period];
  for (const v of [min, max]) if (v !== null && (v < b.min || v > b.max)) return 'suspicious';
  if (min !== null && max !== null && min > 0 && max / min > MAX_SPREAD) return 'suspicious';
  return 'plausible';
}
