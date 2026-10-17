import '../domain/entities/job_posting.dart';

/// Local copy of a catalogue posting, for reading it again without a connection.
///
/// Unlike [jobToSnapshot] (the 16 KB snapshot kept with favourites and applications, which has no description) this keeps the text the person
/// read, in its ORIGINAL language: translations are never stored here (the translation cache keys them by job, field, language and a hash of the original
/// text). The description is cut at [maxDescription] characters so a long listing cannot fill the device.
const maxCachedDescription = 6000;

Map<String, Object?> jobToCacheJson(JobPosting j) => {
  's': j.source,
  'x': j.externalId,
  'c': j.company,
  't': j.title,
  'u': j.originalUrl,
  if (j.applyUrl != null) 'a': j.applyUrl,
  if (j.country != null) 'co': j.country,
  if (j.city != null) 'ci': j.city,
  if (j.workMode != WorkMode.unspecified) 'w': j.workMode.name,
  if (j.contractType != null) 'ct': j.contractType,
  if (j.salaryMin != null) 'smin': j.salaryMin,
  if (j.salaryMax != null) 'smax': j.salaryMax,
  if (j.salaryCurrency != null) 'scur': j.salaryCurrency,
  if (j.salaryPeriod != null) 'sper': j.salaryPeriod!.name,
  if (j.publishedAt != null) 'p': j.publishedAt!.toUtc().toIso8601String(),
  if (j.sourceName != null) 'sn': j.sourceName,
  if (j.language != null) 'l': j.language,
  if (j.geoRestrictions.isNotEmpty) 'g': j.geoRestrictions,
  if (j.description != null && j.description!.isNotEmpty)
    'd': j.description!.length > maxCachedDescription
        ? j.description!.substring(0, maxCachedDescription)
        : j.description,
  if (j.skills.isNotEmpty) 'k': j.skills,
};

/// The posting stored by [jobToCacheJson], or null when the entry is damaged (a bad entry is dropped, never shown half-read).
JobPosting? jobFromCacheJson(Object? raw) {
  if (raw is! Map) return null;
  String? s(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
  double? n(Object? v) => v is num ? v.toDouble() : null;
  List<String> list(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is String && e.isNotEmpty) e,
        ]
      : const [];
  final source = s(raw['s']);
  final id = s(raw['x']);
  final title = s(raw['t']);
  final url = s(raw['u']);
  if (source == null || id == null || title == null || url == null) return null;
  return JobPosting(
    source: source,
    externalId: id,
    company: raw['c'] is String ? raw['c'] as String : '',
    title: title,
    originalUrl: url,
    applyUrl: s(raw['a']),
    country: s(raw['co']),
    city: s(raw['ci']),
    workMode: WorkMode.values.firstWhere(
      (m) => m.name == raw['w'],
      orElse: () => WorkMode.unspecified,
    ),
    contractType: s(raw['ct']),
    salaryMin: n(raw['smin']),
    salaryMax: n(raw['smax']),
    salaryCurrency: s(raw['scur']),
    salaryPeriod: SalaryPeriod.values
        .where((p) => p.name == raw['sper'])
        .firstOrNull,
    publishedAt: DateTime.tryParse(s(raw['p']) ?? '')?.toUtc(),
    sourceName: s(raw['sn']),
    language: s(raw['l']),
    geoRestrictions: list(raw['g']),
    description: s(raw['d']),
    skills: list(raw['k']),
  );
}
