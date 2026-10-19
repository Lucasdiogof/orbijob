import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/data/supabase_job_catalog_repository.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';

import 'fake_backend.dart';

/// The exact HTTP requests the catalogue repository sends, recorded for a fixed set of searches and compared with
/// `catalog_requests.golden.json`. That file is what the CI job `catalog-postgrest` replays against a REAL PostgREST
/// running on the REAL migrated schema (scripts/supabase/catalog_postgrest_contract.mjs): a mocked client proves what
/// we send, the replay proves the server accepts it and answers with the right rows and types.
///
/// If the repository's queries change on purpose, regenerate the file:
///   UPDATE_GOLDEN=1 flutter test test/supabase/catalog_contract_test.dart
/// and update the expectations in the Node script if the answers should change.
final _now = DateTime.utc(2026, 10, 10, 12);

const _goldenPath = 'test/supabase/catalog_requests.golden.json';

typedef _Call = Future<void> Function(SupabaseJobCatalogRepository repo);

/// Any valid row, so the repository does not follow up with the "is there an authorised source?" request.
const _anyRow = {
  'source_id': 'jobicy',
  'external_id': 'x',
  'title': 'x',
  'company': 'x',
  'original_url': 'https://jobicy.com/jobs/x',
  'status': 'open',
  'job_sources': {
    'id': 'jobicy',
    'attribution': 'x',
    'can_redistribute': true,
    'status': 'CONDITIONAL',
  },
};

final _scenarios = <String, ({_Call call, bool emptyCatalogue})>{
  'browse': (call: (r) => r.search(''), emptyCatalogue: false),
  'text_flutter': (call: (r) => r.search('flutter'), emptyCatalogue: false),
  'text_partial_title': (call: (r) => r.search('engin'), emptyCatalogue: false),
  'text_hostile': (
    call: (r) => r.search('a),status.eq.closed,(b"c*d%e'),
    emptyCatalogue: false,
  ),
  'country_us': (
    call: (r) => r.search('', filters: const JobFilters(countryCode: 'us')),
    emptyCatalogue: false,
  ),
  'country_pt': (
    call: (r) => r.search('', filters: const JobFilters(countryCode: 'PT')),
    emptyCatalogue: false,
  ),
  'country_de': (
    call: (r) => r.search('', filters: const JobFilters(countryCode: 'DE')),
    emptyCatalogue: false,
  ),
  'mode_onsite': (
    call: (r) =>
        r.search('', filters: const JobFilters(workModes: {WorkMode.onsite})),
    emptyCatalogue: false,
  ),
  'mode_remote_hybrid': (
    call: (r) => r.search(
      '',
      filters: const JobFilters(workModes: {WorkMode.remote, WorkMode.hybrid}),
    ),
    emptyCatalogue: false,
  ),
  'published_7d': (
    call: (r) =>
        r.search('', filters: const JobFilters(publishedWithinDays: 7)),
    emptyCatalogue: false,
  ),
  'only_with_salary': (
    call: (r) => r.search('', filters: const JobFilters(onlyWithSalary: true)),
    emptyCatalogue: false,
  ),
  'text_and_country_two_or_groups': (
    call: (r) =>
        r.search('developer', filters: const JobFilters(countryCode: 'PT')),
    emptyCatalogue: false,
  ),
  'text_and_country_overlap': (
    call: (r) =>
        r.search('nurse', filters: const JobFilters(countryCode: 'US')),
    emptyCatalogue: false,
  ),
  'all_filters': (
    call: (r) => r.search(
      '',
      filters: const JobFilters(
        workModes: {WorkMode.remote},
        publishedWithinDays: 7,
        onlyWithSalary: true,
        countryCode: 'US',
      ),
    ),
    emptyCatalogue: false,
  ),
  'page_1': (call: (r) => r.search('', limit: 3), emptyCatalogue: false),
  'page_2': (
    call: (r) => r.search('', offset: 3, limit: 3),
    emptyCatalogue: false,
  ),
  'empty_catalogue_source_check': (
    call: (r) => r.search('nurse'),
    emptyCatalogue: true,
  ),
};

Future<Map<String, Object?>> _record() async {
  final out = <Map<String, Object?>>[];
  for (final e in _scenarios.entries) {
    final b = FakeBackend(
      respond: (m, url, _) => (200, e.value.emptyCatalogue ? [] : [_anyRow]),
    );
    await e.value.call(SupabaseJobCatalogRepository(b.client, now: () => _now));
    out.add({
      'name': e.key,
      'requests': [
        for (final r in b.requests)
          {
            'method': r.method,
            'path': r.request.url.path,
            'query': r.request.url.query,
          },
      ],
    });
  }
  return {'version': 1, 'clock': _now.toIso8601String(), 'scenarios': out};
}

String _pretty(Object o) =>
    '${const JsonEncoder.withIndent('  ').convert(o)}\n';

void main() {
  test('the requests the repository sends match the golden file replayed against a real PostgREST in CI', () async {
    final actual = _pretty(await _record());
    final file = File(_goldenPath);
    if (Platform.environment['UPDATE_GOLDEN'] == '1') {
      file.writeAsStringSync(actual);
      return;
    }
    expect(
      file.existsSync(),
      isTrue,
      reason: 'generate it with UPDATE_GOLDEN=1',
    );
    expect(
      actual,
      file.readAsStringSync().replaceAll('\r\n', '\n'),
      reason:
          'the repository now sends different queries than the ones validated against PostgREST; '
          'regenerate with UPDATE_GOLDEN=1 and let the catalog-postgrest CI job re-validate them',
    );
  });

  test('the golden file only contains reads of the two public tables', () {
    final g = jsonDecode(File(_goldenPath).readAsStringSync()) as Map;
    for (final s in g['scenarios'] as List) {
      for (final r in (s as Map)['requests'] as List) {
        expect((r as Map)['method'], 'GET');
        expect(r['path'], anyOf('/rest/v1/jobs', '/rest/v1/job_sources'));
      }
    }
  });
}
