import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/load_status.dart';
import 'package:orbijob/features/preferences/presentation/preferences_cubit.dart';
import 'package:orbijob/features/preferences/presentation/saved_searches_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';

void main() {
  group('PreferencesCubit', () {
    late FakePreferences repo;
    late PreferencesCubit c;
    setUp(() {
      repo = FakePreferences();
      c = PreferencesCubit(repo);
    });

    test(
      'without an account nothing is persisted (device-only choices)',
      () async {
        final n = PreferencesCubit(null);
        await n.load();
        expect(n.state.synced, isFalse);
        expect(await n.setTheme('dark'), isFalse);
        expect(n.state.prefs.theme, 'system');
      },
    );

    test('a failed load is not "synced": a change would overwrite unknown data, so it is not sent', () async {
      repo.error = const sb.AuthApiException('x', statusCode: '401');
      await c.load();
      expect(c.state.synced, isFalse);
      repo.error = null;
      await c.setTheme('dark');
      expect(repo.saves, 0);
    });

    test('theme, language and countries are saved to the account', () async {
      await c.load();
      expect(c.state.status, LoadStatus.ready);
      expect(await c.setTheme('dark'), isTrue);
      expect(await c.setLocale('es'), isTrue);
      expect(await c.addCountry(' de '), isTrue);
      expect(await c.addCountry('pt'), isTrue);
      expect(repo.stored.theme, 'dark');
      expect(repo.stored.locale, 'es');
      expect(repo.stored.countriesOfInterest, ['DE', 'PT']);
      expect(await c.removeCountry('DE'), isTrue);
      expect(repo.stored.countriesOfInterest, ['PT']);
      expect(await c.setLocale(null), isTrue);
      expect(repo.stored.locale, isNull);
    });

    test('invalid, repeated and excess countries are refused', () async {
      await c.load();
      for (final bad in ['', 'B', 'BRA', '1A', 'B R']) {
        expect(await c.addCountry(bad), isFalse, reason: bad);
      }
      expect(await c.addCountry('BR'), isTrue);
      expect(await c.addCountry('br'), isFalse);
      expect(c.state.actionFailure, DataFailureKind.invalidInput);
      for (final a in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
        await c.addCountry('${a}X');
        await c.addCountry('${a}Y');
      }
      expect(
        c.state.prefs.countriesOfInterest.length,
        PreferencesCubit.maxCountries,
      );
      expect(await c.addCountry('ZZ'), isFalse);
    });

    test('a refused save is rolled back and reported', () async {
      await c.load();
      repo.error = const sb.PostgrestException(message: 'x', code: '42501');
      expect(await c.setTheme('dark'), isFalse);
      expect(c.state.prefs.theme, 'system');
      expect(c.state.actionFailure, DataFailureKind.denied);
    });
  });

  group('SavedSearchesCubit', () {
    late FakeSavedSearches repo;
    late SavedSearchesCubit c;
    setUp(() {
      repo = FakeSavedSearches();
      c = SavedSearchesCubit(repo);
    });

    test('saves, lists, dedupes and removes (server side, unlike device-only recents)', () async {
      await c.load();
      expect(await c.save('  electrician '), isTrue);
      expect(await c.save('electrician'), isFalse);
      expect(c.state.actionFailure, DataFailureKind.duplicate);
      expect(await c.save('nurse', countryCode: 'DE'), isTrue);
      expect(repo.rows.map((r) => r.query), [
        {'term': 'nurse', 'country': 'DE'},
        {'term': 'electrician'},
      ]);
      expect(c.isSaved('nurse', countryCode: 'DE'), isTrue);
      expect(c.isSaved('nurse'), isFalse);
      await c.remove(c.state.items.first.id);
      expect(c.state.items.map(SavedSearchesCubit.termOf), ['electrician']);
    });

    test('empty and over-long terms are refused', () async {
      await c.load();
      expect(await c.save('   '), isFalse);
      expect(
        await c.save('x' * (SavedSearchesCubit.maxTermLength + 1)),
        isFalse,
      );
      expect(repo.rows, isEmpty);
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

    test('without a backend: not configured', () async {
      final n = SavedSearchesCubit(null);
      expect(await n.save('a'), isFalse);
      expect(n.state.actionFailure, DataFailureKind.notConfigured);
    });
  });
}
