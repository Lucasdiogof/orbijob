import 'package:flutter/widgets.dart';

import '../../../core/format/country_names.dart';
import '../../../core/format/job_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../search/domain/entities/job_posting.dart';
import '../../search/presentation/widgets/area_chips.dart';
import '../../search/presentation/widgets/health_specialty_chips.dart';
import '../../search/presentation/widgets/search_filters_panel.dart'
    show continentLabel;
import '../domain/saved_search.dart';
import '../domain/search_spec.dart';

/// The parts of a search in reading order, as short labels: the text, the place, the area, the work modes and the other filters.
/// Used for the chips of a saved search and to name one that has no name.
List<String> describeSpec(SearchSpec spec, AppLocalizations l, String lang) {
  final s = spec.canonical;
  final f = s.filters;
  final country = s.countryCode;
  return [
    if (s.term.isNotEmpty) s.term,
    if (country != null) countryName(country, lang) ?? country,
    if (country == null && f.continent != null) continentLabel(f.continent!, l),
    if (f.area != null) areaLabel(f.area!, l),
    if (f.specialty != null) specialtyLabel(f.specialty!, l),
    for (final m in WorkMode.values)
      if (f.workModes.contains(m) && m != WorkMode.unspecified)
        workModeLabel(m, l),
    if (f.publishedWithinDays != null)
      f.publishedWithinDays == 7
          ? l.filterPublished7
          : l.ssSpecDays(f.publishedWithinDays!),
    if (f.onlyWithSalary) l.filterWithSalary,
  ];
}

/// A name for a search that has none: its parts joined, or "All jobs".
String defaultSearchName(SearchSpec spec, AppLocalizations l, String lang) {
  final parts = describeSpec(spec, l, lang);
  if (parts.isEmpty) return l.ssAllJobs;
  final text = parts.take(3).join(' · ');
  return text.length > 80 ? text.substring(0, 80).trimRight() : text;
}

String savedSearchTitle(SavedSearch s, AppLocalizations l, String lang) =>
    s.name ?? defaultSearchName(s.spec, l, lang);

String frequencyLabel(AlertFrequency f, AppLocalizations l) => switch (f) {
  AlertFrequency.instant => l.ssFreqInstant,
  AlertFrequency.daily => l.ssFreqDaily,
  AlertFrequency.weekly => l.ssFreqWeekly,
};

String langOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode;
