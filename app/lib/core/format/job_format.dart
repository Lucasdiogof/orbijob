import 'package:intl/intl.dart';

import '../../features/search/domain/entities/job_posting.dart';
import '../../l10n/app_localizations.dart';
import 'country_names.dart';
import 'geo_eligibility.dart';
import 'salary_check.dart';

/// "R$ 9.000–12.000/mês", "A partir de US$ 90.000/ano", "Até US$ 110.000/ano". Returns null when the source gives no salary, or when
/// the figure is implausible (held back until the source confirms it, see salary_check.dart): nothing is invented or "fixed".
String? formatSalary(JobPosting j, AppLocalizations l) {
  final kind = salaryKind(j);
  if (kind == SalaryKind.unknown || kind == SalaryKind.suspicious) return null;
  final min = j.salaryMin;
  final max = j.salaryMax;
  final nf = NumberFormat.decimalPattern(l.localeName)
    ..maximumFractionDigits = 0;
  final cur = j.salaryCurrency;
  final symbol = cur == null
      ? ''
      : NumberFormat.simpleCurrency(
          locale: l.localeName,
          name: cur,
        ).currencySymbol;
  final value = switch (kind) {
    SalaryKind.range => '${nf.format(min)}–${nf.format(max)}',
    SalaryKind.from => nf.format(min),
    _ => nf.format(max ?? min),
  };
  final period = switch (j.salaryPeriod) {
    SalaryPeriod.hour => l.perHour,
    SalaryPeriod.day => l.perDay,
    SalaryPeriod.week => l.perWeek,
    SalaryPeriod.month => l.perMonth,
    SalaryPeriod.year => l.perYear,
    null => '',
  };
  final amount = '${symbol.isEmpty ? '' : '$symbol '}$value$period';
  return switch (kind) {
    SalaryKind.from => l.salaryFrom(amount),
    SalaryKind.upTo => l.salaryUpTo(amount),
    _ => amount,
  };
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

/// Where the job is, for the card and the detail header: "city · Country" with the country in the interface language.
/// A remote job tied to places shows them (countries by name, regions as published); an explicit "Anywhere" says so; a job with
/// no usable location shows nothing here (the detail screen then says the eligibility is not stated).
String? placeLabel(JobPosting j, AppLocalizations l) {
  final lang = l.localeName.split('_').first;
  final parts = <String>[
    if (j.city != null && j.city!.isNotEmpty) j.city!,
    if (j.country != null && j.country!.isNotEmpty)
      countryName(j.country!, lang) ?? j.country!,
  ];
  if (parts.isNotEmpty) return parts.join(' · ');
  final g = geoEligibility(j, lang);
  if (g.kind == GeoKind.anywhere) return l.locationAnywhere;
  if (g.places.isNotEmpty) return g.places.join(', ');
  return null;
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
