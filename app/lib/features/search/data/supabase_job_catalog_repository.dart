import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/job_posting.dart';
import '../domain/job_filters.dart';
import '../domain/search_repository.dart';

/// Reads the public job catalogue (`public.jobs`) with the publishable key and the signed-in user's session, if any.
/// Row Level Security is the real gate: it only exposes jobs of sources marked `can_redistribute` with status
/// `READY` or `CONDITIONAL`. The same two conditions are repeated here, so a policy mistake on the server would
/// still not put an unauthorised job on screen.
///
/// Only columns that exist are used. Not offered, because the schema cannot answer them: profession filter
/// (`isco08` is empty for most sources) and salary ranges (amounts in different currencies and periods are not
/// comparable).
class SupabaseJobCatalogRepository implements SearchRepository {
  SupabaseJobCatalogRepository(
    this._client, {
    DateTime Function()? now,
    this.maxVerificationAge = defaultMaxVerificationAge,
  }) : _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _now;

  static const allowedSourceStatuses = ['READY', 'CONDITIONAL'];

  /// A job is shown as open only while the source has vouched for it recently (`jobs.last_checked_at` is moved by every feed pass
  /// and every "still active" answer of the sync). Past this age nobody can guarantee it is still open, so it is not offered; it
  /// returns by itself as soon as a check confirms it. Same value as EXPIRE_MS in worker/src/freshness.ts.
  static const defaultMaxVerificationAge = Duration(hours: 72);

  /// Null turns the age filter OFF. Only for the bootstrap window in which the revalidation of the stored jobs is not yet running
  /// (see docs/JOBICY_SYNC_PLAN.md); the injector never passes null unless the build says so on purpose.
  final Duration? maxVerificationAge;

  static const _columns =
      'id,source_id,external_id,company,title,description,country,city,language,work_mode,contract_type,'
      'salary_min,salary_max,salary_currency,salary_period,published_at,original_url,apply_url,status,'
      'geo_restrictions,job_sources!inner(id,attribution,can_redistribute,status)';

  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async {
    final f = countryCode != null && filters.countryCode == null
        ? filters.copyWith(countryCode: countryCode)
        : filters;
    final safeLimit = limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;

    var q = _client
        .from('jobs')
        .select(_columns)
        .eq('status', 'open')
        .eq('job_sources.can_redistribute', true)
        .inFilter('job_sources.status', allowedSourceStatuses);
    final maxAge = maxVerificationAge;
    if (maxAge != null) {
      q = q.gte(
        'last_checked_at',
        _now().toUtc().subtract(maxAge).toIso8601String(),
      );
    }

    final term = sanitizeSearchTerm(query);
    if (term.isNotEmpty) {
      // websearch over the generated `search` column (title, company, description) OR a substring of the title
      // (served by the trigram index), so a partial word such as "engin" still finds "Engineer".
      q = q.or('search.wfts(simple).$term,title.ilike.*$term*');
    }
    final country = normalizeCountry(f.countryCode);
    if (country != null) {
      q = q.or(
        'country.eq.$country,geo_restrictions.cs.{$country},'
        'and(work_mode.eq.remote,geo_restrictions.cs.{Anywhere})',
      );
    }
    if (f.workModes.isNotEmpty) {
      q = q.inFilter('work_mode', [
        for (final m in f.workModes)
          if (m != WorkMode.unspecified) m.name,
      ]);
    }
    final days = f.publishedWithinDays;
    if (days != null && days > 0) {
      q = q.gte(
        'published_at',
        _now().toUtc().subtract(Duration(days: days)).toIso8601String(),
      );
    }
    if (f.onlyWithSalary) {
      q = q
          .or('salary_min.not.is.null,salary_max.not.is.null')
          .not('salary_currency', 'is', null)
          .not('salary_period', 'is', null);
    }

    // `id` breaks ties so pages never overlap or skip jobs that share a publication time.
    final rows = await q
        .order('published_at', ascending: false, nullsFirst: false)
        .order('id', ascending: false)
        .range(safeOffset, safeOffset + safeLimit);

    final hasMore = rows.length > safeLimit;
    final page = rows.take(safeLimit);
    final jobs = <ScoredJob>[for (final r in page) ?_scored(r)];

    if (jobs.isEmpty && !hasMore && safeOffset == 0) {
      // Nothing came back: tell "no authorised source exists" apart from "the source has no matching jobs".
      if (!await _hasAuthorisedSource()) {
        return const SearchResult(jobs: [], hasIntegratedSource: false);
      }
    }
    return SearchResult(
      jobs: jobs,
      hasIntegratedSource: true,
      hasMore: hasMore,
      consumed: rows.length > safeLimit ? safeLimit : rows.length,
    );
  }

  ScoredJob? _scored(Object? row) {
    final j = jobFromCatalogRow(row);
    return j == null ? null : ScoredJob(j);
  }

  Future<bool> _hasAuthorisedSource() async {
    final rows = await _client
        .from('job_sources')
        .select('id')
        .eq('can_redistribute', true)
        .inFilter('status', allowedSourceStatuses)
        .limit(1);
    return rows.isNotEmpty;
  }
}

/// User text -> something safe to place inside a PostgREST `or=(...)` list and a tsquery: letters, digits and a few
/// harmless marks only. Commas, parentheses, quotes, wildcards and operators are dropped, so the text can never
/// change the structure of the filter.
String sanitizeSearchTerm(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s+#\-]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.length > 100 ? cleaned.substring(0, 100).trim() : cleaned;
}

/// `us`/`US` -> `US`; anything that is not two ASCII letters is ignored.
String? normalizeCountry(String? code) {
  final c = code?.trim().toUpperCase();
  return c != null && RegExp(r'^[A-Z]{2}$').hasMatch(c) ? c : null;
}

const _sourceNames = {'jobicy': 'Jobicy'};

/// A catalogue row -> [JobPosting], or null when the row cannot be shown honestly: not open, source not authorised,
/// no usable link, or missing identity. Optional values that are inconsistent are dropped, never repaired.
JobPosting? jobFromCatalogRow(Object? raw) {
  if (raw is! Map) return null;
  String? s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  if (raw['status'] != 'open') return null;
  final src = raw['job_sources'];
  final source = src is Map
      ? src
      : (src is List && src.isNotEmpty && src.first is Map
            ? src.first as Map
            : null);
  if (source == null ||
      source['can_redistribute'] != true ||
      !SupabaseJobCatalogRepository.allowedSourceStatuses.contains(
        source['status'],
      )) {
    return null;
  }

  final sourceId = s(raw['source_id']);
  final externalId = s(raw['external_id']);
  final title = s(raw['title']);
  final originalUrl = _httpUrl(raw['original_url']);
  if (sourceId == null ||
      externalId == null ||
      title == null ||
      originalUrl == null) {
    return null;
  }

  final salary = _salary(raw);
  final geo = raw['geo_restrictions'];
  return JobPosting(
    source: sourceId,
    externalId: externalId,
    company: raw['company'] is String ? (raw['company'] as String).trim() : '',
    title: title,
    originalUrl: originalUrl,
    applyUrl: _httpUrl(raw['apply_url']),
    country: s(raw['country'])?.toUpperCase(),
    city: s(raw['city']),
    workMode: WorkMode.values.firstWhere(
      (m) => m.name == raw['work_mode'],
      orElse: () => WorkMode.unspecified,
    ),
    contractType: s(raw['contract_type']),
    salaryMin: salary?.$1,
    salaryMax: salary?.$2,
    salaryCurrency: salary?.$3,
    salaryPeriod: salary?.$4,
    publishedAt: DateTime.tryParse(s(raw['published_at']) ?? '')?.toUtc(),
    sourceName: _sourceNames[sourceId] ?? s(source['attribution']) ?? sourceId,
    language: s(raw['language']),
    geoRestrictions: geo is List
        ? [
            for (final g in geo)
              if (g is String && g.trim().isNotEmpty) g.trim(),
          ]
        : const [],
    description: s(raw['description']),
  );
}

/// http(s) URLs only: anything else (javascript:, data:, relative, garbage) is not a link we will open.
String? _httpUrl(Object? v) {
  if (v is! String) return null;
  final u = Uri.tryParse(v.trim());
  if (u == null || !(u.scheme == 'https' || u.scheme == 'http')) return null;
  return u.host.isEmpty ? null : u.toString();
}

double? _num(Object? v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

/// A salary is shown only when amounts, currency and period are all present and consistent.
(double?, double?, String, SalaryPeriod)? _salary(Map raw) {
  final min = _num(raw['salary_min']);
  final max = _num(raw['salary_max']);
  final cur = raw['salary_currency'];
  final period = SalaryPeriod.values
      .where((p) => p.name == raw['salary_period'])
      .firstOrNull;
  if ((min == null && max == null) ||
      (min != null && min < 0) ||
      (max != null && max < 0) ||
      cur is! String ||
      !RegExp(r'^[A-Z]{3}$').hasMatch(cur) ||
      period == null ||
      (min != null && max != null && min > max)) {
    return null;
  }
  return (min, max, cur, period);
}

/// `--dart-define=JOB_MAX_VERIFICATION_HOURS=`: 72 (default) or 0 (filter OFF, temporary). Any other value is ignored and 72 is used:
/// the window is not meant to be stretched to hide a sync that is not running.
Duration? jobMaxVerificationAge(int hours) =>
    hours == 0 ? null : SupabaseJobCatalogRepository.defaultMaxVerificationAge;
