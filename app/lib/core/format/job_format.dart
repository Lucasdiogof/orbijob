import 'package:intl/intl.dart';

import '../../features/search/domain/entities/job_posting.dart';
import '../../l10n/app_localizations.dart';

/// "R$ 9.000–12.000/mês". Returns null when the source gives no salary: nothing is invented.
String? formatSalary(JobPosting j, AppLocalizations l) {
  final min = j.salaryMin;
  final max = j.salaryMax;
  if (min == null && max == null) return null;
  final nf = NumberFormat.decimalPattern(l.localeName)
    ..maximumFractionDigits = 0;
  final cur = j.salaryCurrency;
  final symbol = cur == null
      ? ''
      : NumberFormat.simpleCurrency(
          locale: l.localeName,
          name: cur,
        ).currencySymbol;
  final value = (min != null && max != null && min != max)
      ? '${nf.format(min)}–${nf.format(max)}'
      : nf.format(min ?? max);
  final period = switch (j.salaryPeriod) {
    SalaryPeriod.hour => l.perHour,
    SalaryPeriod.day => l.perDay,
    SalaryPeriod.week => l.perWeek,
    SalaryPeriod.month => l.perMonth,
    SalaryPeriod.year => l.perYear,
    null => '',
  };
  return '${symbol.isEmpty ? '' : '$symbol '}$value$period';
}

/// Relative publication date ("Posted 3 days ago"); null when the source gives no date.
String? formatPublished(DateTime? published, DateTime now, AppLocalizations l) {
  if (published == null) return null;
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(published.year, published.month, published.day)).inDays;
  if (days <= 0) return l.publishedToday;
  if (days == 1) return l.publishedYesterday;
  if (days < 7) return l.publishedDaysAgo(days);
  if (days < 30) return l.publishedWeeksAgo(days ~/ 7);
  return l.publishedMonthsAgo(days ~/ 30);
}

String workModeLabel(WorkMode m, AppLocalizations l) => switch (m) {
  WorkMode.remote => l.workModeRemote,
  WorkMode.hybrid => l.workModeHybrid,
  WorkMode.onsite => l.workModeOnsite,
  WorkMode.unspecified => '',
};

String? placeLabel(JobPosting j) {
  final parts = <String>[
    if (j.city != null && j.city!.isNotEmpty) j.city!,
    if (j.country != null && j.country!.isNotEmpty) j.country!,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Native name of a language (never translated, so a reader recognises it in any interface language).
String? nativeLanguageName(String? code) => switch (code?.toLowerCase()) {
  'en' => 'English',
  'pt' => 'Português',
  'es' => 'Español',
  'de' => 'Deutsch',
  'fr' => 'Français',
  'it' => 'Italiano',
  'nl' => 'Nederlands',
  final c? when c.isNotEmpty => c.toUpperCase(),
  _ => null,
};
