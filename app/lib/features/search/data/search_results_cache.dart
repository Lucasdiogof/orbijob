import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/job_posting.dart';
import '../domain/job_filters.dart';
import 'job_cache_codec.dart';
import 'supabase_job_catalog_repository.dart'
    show normalizeCountry, sanitizeSearchTerm;

/// The first page of a search the person already ran online, kept to reopen it without a connection.
class CachedSearch {
  const CachedSearch({
    required this.key,
    required this.query,
    required this.savedAt,
    required this.jobs,
    required this.hasIntegratedSource,
  });
  final String key;
  final String query;

  /// When the page was read from the catalogue: shown to the person, never hidden.
  final DateTime savedAt;
  final List<JobPosting> jobs;
  final bool hasIntegratedSource;
}

/// A job kept by its catalogue id, to open the job of a notification without a connection.
class CachedJob {
  const CachedJob({required this.id, required this.savedAt, required this.job});
  final String id;
  final DateTime savedAt;
  final JobPosting job;
}

/// Everything that makes two searches the same: the sanitised text, the country and the filters. The key is stable across launches.
String searchCacheKey(
  String query, {
  String? countryCode,
  JobFilters filters = const JobFilters(),
}) {
  final country = normalizeCountry(filters.countryCode ?? countryCode);
  final modes = [
    for (final m in WorkMode.values)
      if (filters.workModes.contains(m) && m != WorkMode.unspecified) m.name,
  ];
  return [
    sanitizeSearchTerm(query).toLowerCase(),
    country ?? '',
    modes.join('+'),
    filters.area?.name ?? '',
    filters.specialty?.name ?? '',
    filters.continent?.name ?? '',
    '${filters.publishedWithinDays ?? ''}',
    filters.onlyWithSalary ? 'salary' : '',
  ].join('|');
}

/// Where the pages of searches already made are kept (device storage only: nothing is sent anywhere).
abstract class SearchResultsCache {
  Future<CachedSearch?> read(String key);
  Future<void> write(CachedSearch entry);

  /// One job kept by its catalogue id (the job a notification points at), or null when it was never kept or is older than the age limit.
  Future<CachedJob?> readJob(String id);
  Future<void> writeJob(CachedJob entry);

  /// Forgets everything (sign-out, "clear" in Settings).
  Future<void> clear();
}

class MemorySearchResultsCache implements SearchResultsCache {
  MemorySearchResultsCache({
    this.now = DateTime.now,
    this.maxAge = defaultMaxAge,
  });
  final DateTime Function() now;
  final Duration maxAge;
  final entries = <String, CachedSearch>{};
  final jobs = <String, CachedJob>{};
  @override
  Future<CachedJob?> readJob(String id) async {
    final e = jobs[id];
    return e == null || now().difference(e.savedAt) > maxAge ? null : e;
  }

  @override
  Future<void> writeJob(CachedJob entry) async => jobs[entry.id] = entry;

  @override
  Future<CachedSearch?> read(String key) async {
    final e = entries[key];
    return e == null || now().difference(e.savedAt) > maxAge ? null : e;
  }

  @override
  Future<void> write(CachedSearch entry) async => entries[entry.key] = entry;
  @override
  Future<void> clear() async {
    entries.clear();
    jobs.clear();
  }

  static const defaultMaxAge = Duration(days: 14);
}

/// Persistent, bounded and expiring. Listings are volatile: an entry older than [maxAge] is not offered (the person is told to connect), at most
/// [maxEntries] searches are kept (the oldest written go first) and each description is cut (see [maxCachedDescription]), so the store stays well
/// under 1 MB. A damaged entry or a damaged store is dropped, never shown half-read and never allowed to break the app.
class PrefsSearchResultsCache implements SearchResultsCache {
  PrefsSearchResultsCache(
    this._prefs, {
    this.now = DateTime.now,
    this.maxAge = MemorySearchResultsCache.defaultMaxAge,
    this.maxEntries = 12,
    this.maxJobsPerEntry = 40,
  });

  final SharedPreferences _prefs;
  final DateTime Function() now;
  final Duration maxAge;
  final int maxEntries;
  final int maxJobsPerEntry;
  static const storeKey = 'search.cache.v1';
  static const jobsKey = 'search.cache.jobs.v1';
  static const maxJobs = 40;

  List<Map<String, Object?>> _loadJobs() {
    try {
      final raw = _prefs.getString(jobsKey);
      if (raw == null) return [];
      final data = jsonDecode(raw);
      return data is List
          ? [
              for (final e in data)
                if (e is Map<String, Object?>) e,
            ]
          : [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<CachedJob?> readJob(String id) async {
    for (final e in _loadJobs()) {
      if (e['k'] != id) continue;
      final at = DateTime.tryParse('${e['at']}');
      if (at == null || now().difference(at) > maxAge) return null;
      final job = jobFromCacheJson(e['j']);
      return job == null
          ? null
          : CachedJob(id: id, savedAt: at.toUtc(), job: job);
    }
    return null;
  }

  @override
  Future<void> writeJob(CachedJob entry) async {
    try {
      final all = _loadJobs()..removeWhere((e) => e['k'] == entry.id);
      all.add({
        'k': entry.id,
        'at': entry.savedAt.toUtc().toIso8601String(),
        'j': jobToCacheJson(entry.job),
      });
      final keep = all.length > maxJobs
          ? all.sublist(all.length - maxJobs)
          : all;
      await _prefs.setString(jobsKey, jsonEncode(keep));
    } catch (_) {}
  }

  List<Map<String, Object?>> _load() {
    try {
      final raw = _prefs.getString(storeKey);
      if (raw == null) return [];
      final data = jsonDecode(raw);
      if (data is! List) return [];
      return [
        for (final e in data)
          if (e is Map<String, Object?>) e,
      ];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<CachedSearch?> read(String key) async {
    for (final e in _load()) {
      if (e['k'] != key) continue;
      final at = DateTime.tryParse('${e['at']}');
      if (at == null || now().difference(at) > maxAge) return null;
      final raw = e['j'];
      final jobs = [
        if (raw is List)
          for (final j in raw) ?jobFromCacheJson(j),
      ];
      final hasSource = e['src'] != false;
      if (jobs.isEmpty && hasSource) return null;
      return CachedSearch(
        key: key,
        query: '${e['q'] ?? ''}',
        savedAt: at.toUtc(),
        jobs: jobs,
        hasIntegratedSource: hasSource,
      );
    }
    return null;
  }

  @override
  Future<void> write(CachedSearch entry) async {
    try {
      final all = _load()..removeWhere((e) => e['k'] == entry.key);
      all.add({
        'k': entry.key,
        'q': entry.query,
        'at': entry.savedAt.toUtc().toIso8601String(),
        'src': entry.hasIntegratedSource,
        'j': [
          for (final j in entry.jobs.take(maxJobsPerEntry)) jobToCacheJson(j),
        ],
      });
      final keep = all.length > maxEntries
          ? all.sublist(all.length - maxEntries)
          : all;
      await _prefs.setString(storeKey, jsonEncode(keep));
    } catch (_) {
      // storage full or unavailable: the search simply is not kept
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _prefs.remove(storeKey);
      await _prefs.remove(jobsKey);
    } catch (_) {}
  }
}
