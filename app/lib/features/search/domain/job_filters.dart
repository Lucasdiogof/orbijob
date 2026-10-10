import 'package:equatable/equatable.dart';

import 'entities/job_posting.dart';

/// Filters the `jobs` table can answer with the columns it has. Anything the schema cannot express (profession
/// before `isco08` is filled, salary ranges across currencies and periods) is deliberately not offered.
class JobFilters extends Equatable {
  const JobFilters({
    this.workModes = const {},
    this.publishedWithinDays,
    this.onlyWithSalary = false,
    this.countryCode,
  });

  /// Empty = any mode.
  final Set<WorkMode> workModes;

  /// Only jobs published in the last N days; null = any date.
  final int? publishedWithinDays;

  /// Only jobs that carry a valid salary (amount, currency and period).
  final bool onlyWithSalary;

  /// ISO 3166-1 alpha-2. Matches jobs in that country, jobs that list it as eligible, and remote jobs the source
  /// explicitly marks `Anywhere`. A job with NO usable location (empty list) is unknown, not global, so it does not match.
  /// Region-only restrictions (EMEA, Europe) are not expanded into countries, so they do not match.
  final String? countryCode;

  bool get isActive =>
      workModes.isNotEmpty ||
      publishedWithinDays != null ||
      onlyWithSalary ||
      countryCode != null;

  JobFilters copyWith({
    Set<WorkMode>? workModes,
    int? publishedWithinDays,
    bool clearPublished = false,
    bool? onlyWithSalary,
    String? countryCode,
    bool clearCountry = false,
  }) => JobFilters(
    workModes: workModes ?? this.workModes,
    publishedWithinDays: clearPublished
        ? null
        : (publishedWithinDays ?? this.publishedWithinDays),
    onlyWithSalary: onlyWithSalary ?? this.onlyWithSalary,
    countryCode: clearCountry ? null : (countryCode ?? this.countryCode),
  );

  @override
  List<Object?> get props => [
    workModes,
    publishedWithinDays,
    onlyWithSalary,
    countryCode,
  ];
}
