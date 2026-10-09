import '../domain/entities/job_posting.dart';

/// JSON snapshot of a posting stored with favourites and applications (jsonb columns), so they survive the
/// job leaving the catalogue. Only fields that exist are written; reading ignores unknown keys.
Map<String, Object?> jobToSnapshot(JobPosting j) => {
  'source': j.source,
  'externalId': j.externalId,
  'company': j.company,
  'title': j.title,
  'originalUrl': j.originalUrl,
  if (j.applyUrl != null) 'applyUrl': j.applyUrl,
  if (j.country != null) 'country': j.country,
  if (j.city != null) 'city': j.city,
  if (j.workMode != WorkMode.unspecified) 'workMode': j.workMode.name,
  if (j.contractType != null) 'contractType': j.contractType,
  if (j.salaryMin != null) 'salaryMin': j.salaryMin,
  if (j.salaryMax != null) 'salaryMax': j.salaryMax,
  if (j.salaryCurrency != null) 'salaryCurrency': j.salaryCurrency,
  if (j.salaryPeriod != null) 'salaryPeriod': j.salaryPeriod!.name,
  if (j.publishedAt != null)
    'publishedAt': j.publishedAt!.toUtc().toIso8601String(),
  if (j.sourceName != null) 'sourceName': j.sourceName,
  if (j.language != null) 'language': j.language,
  if (j.geoRestrictions.isNotEmpty) 'geoRestrictions': j.geoRestrictions,
};

/// `source` of postings the user typed in (applications added by hand); their `originalUrl` may be empty.
const manualSource = 'manual';

/// Stable key for a posting across sources: `<source>:<externalId>`.
String jobKey(JobPosting j) => '${j.source}:${j.externalId}';

T? _enum<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

String? _s(Object? v) => v is String && v.isNotEmpty ? v : null;
double? _n(Object? v) => v is num ? v.toDouble() : null;

List<String> _strings(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is String && e.isNotEmpty) e,
      ]
    : const [];

/// Returns null when the snapshot lacks the identity fields (corrupt/foreign data is skipped, not guessed).
JobPosting? jobFromSnapshot(Object? raw) {
  if (raw is! Map) return null;
  final source = _s(raw['source']);
  final id = _s(raw['externalId']);
  final title = _s(raw['title']);
  // A company may be empty (some sources omit it); it must still be text, never a reason to lose the favourite.
  final company = raw['company'] is String ? raw['company'] as String : null;
  // Entries the user adds by hand have no link; every other source must carry one.
  final url = _s(raw['originalUrl']) ?? (source == manualSource ? '' : null);
  if (source == null ||
      id == null ||
      title == null ||
      company == null ||
      url == null) {
    return null;
  }
  return JobPosting(
    source: source,
    externalId: id,
    company: company,
    title: title,
    originalUrl: url,
    applyUrl: _s(raw['applyUrl']),
    country: _s(raw['country']),
    city: _s(raw['city']),
    workMode: _enum(WorkMode.values, raw['workMode']) ?? WorkMode.unspecified,
    contractType: _s(raw['contractType']),
    salaryMin: _n(raw['salaryMin']),
    salaryMax: _n(raw['salaryMax']),
    salaryCurrency: _s(raw['salaryCurrency']),
    salaryPeriod: _enum(SalaryPeriod.values, raw['salaryPeriod']),
    publishedAt: DateTime.tryParse(_s(raw['publishedAt']) ?? ''),
    sourceName: _s(raw['sourceName']),
    language: _s(raw['language']),
    geoRestrictions: _strings(raw['geoRestrictions']),
  );
}
