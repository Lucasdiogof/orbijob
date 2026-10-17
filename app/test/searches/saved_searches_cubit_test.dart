import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/load_status.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_area.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/searches/domain/saved_search.dart';
import 'package:orbijob/features/searches/domain/search_spec.dart';
import 'package:orbijob/features/searches/presentation/saved_searches_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';

void main() {
  late FakeSavedSearches repo;
  late SavedSearchesCubit c;
  setUp(() {
    repo = FakeSavedSearches();
    c = SavedSearchesCubit(repo);
  });

  test(
    'saves, lists, dedupes and removes (server side, unlike device-only recents)',
    () async {
      await c.load();
      expect(await c.save('  electrician '), isTrue);
      expect(await c.save('electrician'), isFalse);
      expect(c.state.actionFailure, DataFailureKind.duplicate);
      expect(await c.save('nurse', countryCode: 'DE'), isTrue);
      expect(repo.rows.map((r) => r.spec.term), ['nurse', 'electrician']);
      expect(repo.rows.first.spec.countryCode, 'DE');
      expect(c.isSaved('nurse', countryCode: 'DE'), isTrue);
      expect(c.isSaved('nurse'), isFalse);
      await c.remove(c.state.items.first.id);
      expect(c.state.items.map((s) => s.spec.term), ['electrician']);
    },
  );

  test(
    'a search with filters and no text is saved whole, and recognised as saved',
    () async {
      await c.load();
      const spec = SearchSpec(
        filters: JobFilters(
          area: JobArea.health,
          workModes: {WorkMode.remote},
          countryCode: 'PT',
        ),
      );
      expect(
        await c.saveSpec(
          spec,
          name: 'Remote health PT',
          alerts: true,
          frequency: AlertFrequency.weekly,
        ),
        isTrue,
      );
      final s = repo.rows.single;
      expect(s.name, 'Remote health PT');
      expect(s.alertsEnabled, isTrue);
      expect(s.frequency, AlertFrequency.weekly);
      expect(s.query['area'], 'health');
      expect(s.query['modes'], ['remote']);
      expect((s.query['match'] as Map)['country'], 'PT');
      expect(c.savedFor(spec)?.id, s.id);
      // the same meaning typed another way is the same search
      expect(
        c
            .savedFor(
              const SearchSpec(
                filters: JobFilters(
                  area: JobArea.health,
                  workModes: {WorkMode.remote},
                ),
                countryCode: 'pt',
              ),
            )
            ?.id,
        s.id,
      );
      expect(await c.saveSpec(spec), isFalse);
      expect(c.state.actionFailure, DataFailureKind.duplicate);
    },
  );

  test(
    'empty, nameless-by-mistake and over-long input is refused before reaching the server',
    () async {
      await c.load();
      expect(await c.save('   '), isFalse);
      expect(await c.saveSpec(const SearchSpec()), isFalse);
      expect(
        await c.save('x' * (SavedSearchesCubit.maxTermLength + 1)),
        isFalse,
      );
      expect(
        await c.saveSpec(const SearchSpec(term: 'a'), name: '  '),
        isFalse,
      );
      expect(
        await c.saveSpec(const SearchSpec(term: 'a'), name: 'n' * 81),
        isFalse,
      );
      expect(c.state.actionFailure, DataFailureKind.invalidInput);
      expect(repo.rows, isEmpty);
    },
  );

  test(
    'rename, edit, alerts and frequency change only what is asked, on the server first',
    () async {
      await c.load();
      await c.saveSpec(const SearchSpec(term: 'nurse'), name: 'Nurses');
      final id = c.state.items.single.id;
      expect(await c.rename(id, '  Night nurses '), isTrue);
      expect(repo.rows.single.name, 'Night nurses');
      expect(repo.rows.single.alertsEnabled, isFalse);
      expect(await c.setAlerts(id, true), isTrue);
      expect(await c.setFrequency(id, AlertFrequency.instant), isTrue);
      expect(repo.rows.single.alertsEnabled, isTrue);
      expect(repo.rows.single.frequency, AlertFrequency.instant);
      expect(repo.rows.single.name, 'Night nurses');
      expect(
        await c.update(id, spec: const SearchSpec(term: 'midwife')),
        isTrue,
      );
      expect(repo.rows.single.spec.term, 'midwife');
      expect(c.state.items.single.spec.term, 'midwife');
      expect(await c.rename(id, ''), isFalse);
      expect(await c.update(id, spec: const SearchSpec()), isFalse);
      expect(c.state.items.single.name, 'Night nurses');
    },
  );

  test('a failed change leaves the list exactly as it was', () async {
    await c.load();
    await c.saveSpec(const SearchSpec(term: 'nurse'), name: 'Nurses');
    final id = c.state.items.single.id;
    repo.error = sb.AuthRetryableFetchException(message: 'offline');
    expect(await c.setAlerts(id, true), isFalse);
    expect(c.state.actionFailure, DataFailureKind.network);
    expect(c.state.items.single.alertsEnabled, isFalse);
    expect(c.state.busy, isFalse);
  });

  test('duplicate makes an independent copy with alerts off', () async {
    await c.load();
    await c.saveSpec(
      const SearchSpec(term: 'nurse'),
      name: 'Nurses',
      alerts: true,
      frequency: AlertFrequency.weekly,
    );
    final id = c.state.items.single.id;
    expect(await c.duplicate(id, name: 'Nurses (copy)'), isTrue);
    expect(repo.rows.length, 2);
    final copy = repo.rows.first;
    expect(copy.name, 'Nurses (copy)');
    expect(copy.alertsEnabled, isFalse);
    expect(copy.frequency, AlertFrequency.weekly);
    expect(copy.query, repo.rows.last.query);
    expect(copy.id, isNot(repo.rows.last.id));
  });

  test('at most 20 searches can have alerts on', () async {
    await c.load();
    for (var i = 0; i < SavedSearchesCubit.maxAlerts; i++) {
      expect(
        await c.saveSpec(SearchSpec(term: 'job $i'), name: 'S$i', alerts: true),
        isTrue,
      );
    }
    expect(c.alertCount, SavedSearchesCubit.maxAlerts);
    expect(
      await c.saveSpec(
        const SearchSpec(term: 'one more'),
        name: 'More',
        alerts: true,
      ),
      isFalse,
    );
    expect(c.state.actionFailure, DataFailureKind.quotaExceeded);
    // saving without alerts is still possible, and so is turning one off to make room
    expect(
      await c.saveSpec(const SearchSpec(term: 'one more'), name: 'More'),
      isTrue,
    );
    final extraId = c.state.items.first.id;
    expect(await c.setAlerts(extraId, true), isFalse);
    await c.setAlerts(c.state.items.last.id, false);
    expect(await c.setAlerts(extraId, true), isTrue);
  });

  test('quota (100) and offline are reported', () async {
    await c.load();
    repo.error = const sb.PostgrestException(
      message: 'quota exceeded',
      code: '53400',
    );
    expect(await c.save('a'), isFalse);
    expect(c.state.actionFailure, DataFailureKind.quotaExceeded);
    repo.error = sb.AuthRetryableFetchException(message: 'offline');
    expect(await c.save('b'), isFalse);
    expect(c.state.actionFailure, DataFailureKind.network);
    expect(c.state.items, isEmpty);
  });

  test(
    'signed out: loading reports it, saving is refused without a request',
    () async {
      repo.error = const sb.PostgrestException(
        message: 'JWT expired',
        code: 'PGRST301',
      );
      await c.load();
      expect(c.state.status, LoadStatus.failure);
      expect(needsSignIn(c.state.failure!), isTrue);
      repo.error = null;
      expect(await c.save('a'), isFalse);
      expect(repo.rows, isEmpty);
    },
  );

  test('without a backend: not configured', () async {
    final n = SavedSearchesCubit(null);
    expect(await n.save('a'), isFalse);
    expect(n.state.actionFailure, DataFailureKind.notConfigured);
    await n.load();
    expect(n.state.failure, DataFailureKind.notConfigured);
  });
}
