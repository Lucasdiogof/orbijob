import '../../features/search/domain/entities/job_posting.dart';

/// How a posting's salary should be shown. Mirrors worker/src/salary.ts (same bounds), so a figure the Worker would now hold
/// back is also hidden for records stored before that rule existed.
enum SalaryKind { unknown, range, exact, from, upTo, suspicious }

const _bounds = {
  SalaryPeriod.hour: (1.0, 10000.0),
  SalaryPeriod.day: (5.0, 100000.0),
  SalaryPeriod.week: (20.0, 500000.0),
  SalaryPeriod.month: (100.0, 5000000.0),
  SalaryPeriod.year: (1000.0, 1000000000.0),
};
const _maxSpread = 20;

/// Classifies without ever changing a value: 168/year is `suspicious` (hidden), not "168,000".
SalaryKind salaryKind(JobPosting j) {
  final min = j.salaryMin;
  final max = j.salaryMax;
  final period = j.salaryPeriod;
  if (min == null && max == null) return SalaryKind.unknown;
  // A figure needs its currency and period to mean anything; without them it is not shown.
  if (j.salaryCurrency == null || period == null) return SalaryKind.unknown;
  if (min != null && max != null && min > max) return SalaryKind.suspicious;
  final (lo, hi) = _bounds[period]!;
  for (final v in [min, max]) {
    if (v != null && (v < lo || v > hi)) return SalaryKind.suspicious;
  }
  if (min != null && max != null && min > 0 && max / min > _maxSpread) {
    return SalaryKind.suspicious;
  }
  if (min != null && max != null) {
    return min == max ? SalaryKind.exact : SalaryKind.range;
  }
  return min != null ? SalaryKind.from : SalaryKind.upTo;
}
