import 'package:equatable/equatable.dart';

import '../../search/data/supabase_job_catalog_repository.dart'
    show normalizeCountry, sanitizeSearchTerm;
import '../../search/domain/continent.dart';
import '../../search/domain/entities/job_posting.dart';
import '../../search/domain/health_specialty.dart';
import '../../search/domain/job_area.dart';
import '../../search/domain/job_filters.dart';
import '../../search/domain/search_synonyms.dart';

/// Everything that defines a search: the text, the country and the filters of Explore. It is what a saved search stores.
///
/// Stored as the `query` JSON of `saved_searches` (version 2). The human-readable parameters are kept as names so the search can be reopened and
/// edited; next to them goes a compiled `match` block (the title keywords of the area, the countries of the continent, the other names of the
/// profession...) that the database evaluates when it looks for new jobs, with the same rules as the catalogue query of the app. Version 1
/// searches (`{term, country?}`, saved by earlier builds) are read as a term plus a country.
class SearchSpec extends Equatable {
  const SearchSpec({
    this.term = '',
    this.filters = const JobFilters(),
    String? countryCode,
  }) : _country = countryCode;

  /// What the person typed (sanitised when searching).
  final String term;
  final JobFilters filters;
  final String? _country;

  static const version = 2;

  /// The country that applies: the filter's, otherwise the one the search was started with.
  String? get countryCode => normalizeCountry(filters.countryCode ?? _country);

  bool get isEmpty => term.trim().isEmpty && !filters.isActive;

  /// Same search with the country folded into the filters, so two specs that mean the same thing compare equal.
  SearchSpec get canonical {
    final c = countryCode;
    return SearchSpec(
      term: sanitizeSearchTerm(term),
      filters: c == null
          ? filters.copyWith(clearCountry: true)
          : filters.copyWith(countryCode: c),
    );
  }

  Map<String, dynamic> toQuery() {
    final s = canonical;
    final f = s.filters;
    final country = s.countryCode;
    final modes = [
      for (final m in WorkMode.values)
        if (f.workModes.contains(m) && m != WorkMode.unspecified) m.name,
    ];
    final area = f.area;
    final specialty = f.specialty;
    final continent = country == null ? f.continent : null;
    final groups = <List<String>>[
      if (area != null) area.keywords,
      if (specialty != null) ...[
        specialty.keywords,
        if (specialty.parent != null) specialty.parent!.keywords,
      ],
    ];
    final days = f.publishedWithinDays;
    return {
      'v': version,
      if (s.term.isNotEmpty) 'term': s.term,
      'country': ?country,
      if (f.continent != null) 'continent': f.continent!.name,
      if (area != null) 'area': area.name,
      if (specialty != null) 'specialty': specialty.name,
      if (modes.isNotEmpty) 'modes': modes,
      if (days != null && days > 0) 'days': days,
      if (f.onlyWithSalary) 'salary': true,
      'match': {
        if (s.term.isNotEmpty) ...{
          'term': s.term,
          if (titleSynonyms(s.term).isNotEmpty) 'alts': titleSynonyms(s.term),
        },
        'country': ?country,
        if (continent != null) ...{
          'cc': (continent.countries.toList()..sort()),
          'regions': continent.regions,
        },
        if (modes.isNotEmpty) 'modes': modes,
        if (groups.isNotEmpty) 'title_groups': groups,
        if (days != null && days > 0) 'days': days,
        if (f.onlyWithSalary) 'salary': true,
      },
    };
  }

  /// Reads a stored query (version 1 or 2). Unknown or malformed parts are ignored, never guessed.
  factory SearchSpec.fromQuery(Map<String, dynamic> q) {
    T? byName<T extends Enum>(List<T> values, Object? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    final modes = <WorkMode>{
      if (q['modes'] is List)
        for (final m in q['modes'] as List)
          if (byName(WorkMode.values, m) case final WorkMode w
              when w != WorkMode.unspecified)
            w,
    };
    final days = q['days'];
    final area = byName(JobArea.values, q['area']);
    var filters = JobFilters(
      workModes: modes,
      publishedWithinDays: days is int && days > 0 ? days : null,
      onlyWithSalary: q['salary'] == true,
      countryCode: normalizeCountry(
        q['country'] is String ? q['country'] as String : null,
      ),
      continent: byName(Continent.values, q['continent']),
      area: area,
      specialty: area == null
          ? null
          : byName(HealthSpecialty.values, q['specialty']),
    );
    if (filters.countryCode != null) {
      filters = filters.copyWith(clearContinent: true);
    }
    return SearchSpec(
      term: q['term'] is String ? (q['term'] as String).trim() : '',
      filters: filters,
    );
  }

  @override
  List<Object?> get props => [canonical.term, canonical.filters];
}
