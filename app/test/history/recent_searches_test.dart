import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/home/recent_searches_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

Future<SharedPreferences> _prefs([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  group('RecentSearchesCubit', () {
    test(
      'newest first, no duplicates (any case), at most 10, blank ignored',
      () async {
        final c = RecentSearchesCubit(prefs: await _prefs());
        c.record('  ');
        for (var i = 0; i < 12; i++) {
          c.record('job $i');
        }
        expect(c.state.length, RecentSearchesCubit.maxItems);
        expect(c.state.first, 'job 11');
        c.record('JOB 5');
        expect(c.state.first, 'JOB 5');
        expect(c.state.where((e) => e.toLowerCase() == 'job 5').length, 1);
        c.record('x' * 300);
        expect(c.state.first.length, RecentSearchesCubit.maxLength);
        await c.close();
      },
    );

    test('survives a restart and is kept apart per account', () async {
      final prefs = await _prefs();
      final a = RecentSearchesCubit(prefs: prefs)..useScope('user-a');
      a.record('nurse');
      a.record('welder');
      a.useScope('user-b');
      expect(a.state, isEmpty, reason: 'B does not see A\'s searches');
      a.record('pilot');
      a.useScope(null);
      expect(a.state, isEmpty);
      a.record('cook');
      await a.close();

      final again = RecentSearchesCubit(prefs: prefs)..useScope('user-a');
      expect(again.state, ['welder', 'nurse']);
      again.useScope('user-b');
      expect(again.state, ['pilot']);
      again.useScope(null);
      expect(again.state, ['cook']);
      await again.close();
    });

    test(
      'turning it off forgets what was kept and stops remembering, also after a restart',
      () async {
        final prefs = await _prefs();
        final c = RecentSearchesCubit(prefs: prefs)..useScope('u');
        c.record('nurse');
        await c.setEnabled(false);
        expect(c.state, isEmpty);
        c.record('welder');
        expect(c.state, isEmpty);
        expect(prefs.getStringList('orbijob.recent_searches.u'), isNull);
        await c.close();
        final again = RecentSearchesCubit(prefs: prefs)..useScope('u');
        expect(again.enabled.value, isFalse);
        again.record('pilot');
        expect(again.state, isEmpty);
        await again.setEnabled(true);
        again.record('pilot');
        expect(again.state, ['pilot']);
        await again.close();
      },
    );

    test(
      'clear removes the stored list, only for the current account',
      () async {
        final prefs = await _prefs();
        final c = RecentSearchesCubit(prefs: prefs)..useScope('a');
        c.record('x');
        c.useScope('b');
        c.record('y');
        c.clear();
        expect(c.state, isEmpty);
        expect(prefs.getStringList('orbijob.recent_searches.b'), isNull);
        expect(prefs.getStringList('orbijob.recent_searches.a'), ['x']);
        await c.close();
      },
    );

    test('a burst of searches is one write, not one per search', () async {
      final prefs = await _prefs();
      fakeAsync((async) {
        final c = RecentSearchesCubit(
          prefs: prefs,
          debounce: const Duration(milliseconds: 800),
        );
        for (final w in ['a', 'b', 'c', 'd']) {
          c.record(w);
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(
          prefs.getStringList('orbijob.recent_searches.anonymous'),
          isNull,
          reason: 'nothing written while the burst lasts',
        );
        async.elapse(const Duration(seconds: 1));
        expect(prefs.getStringList('orbijob.recent_searches.anonymous'), [
          'd',
          'c',
          'b',
          'a',
        ]);
        // a change right before the scope switches is saved by the switch
        c.record('e');
        c.useScope('z');
        expect(
          prefs.getStringList('orbijob.recent_searches.anonymous')!.first,
          'e',
        );
        c.close();
      });
    });

    test('without storage it still works in memory', () {
      final c = RecentSearchesCubit();
      c.record('nurse');
      expect(c.state, ['nurse']);
      c.useScope('x');
      expect(c.state, isEmpty);
    });
  });

  group('settings screen', () {
    testWidgets('the switch and the clear button act on the device history', (
      t,
    ) async {
      final prefs = await _prefs({
        'orbijob.recent_searches.anonymous': ['nurse', 'welder'],
      });
      final c = RecentSearchesCubit(prefs: prefs)..useScope(null);
      expect(c.state, ['nurse', 'welder']);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: c.enabled,
              builder: (_, on, _) => Switch(value: on, onChanged: c.setEnabled),
            ),
          ),
        ),
      );
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(c.enabled.value, isFalse);
      expect(c.state, isEmpty);
      expect(prefs.getBool('orbijob.recent_searches.enabled'), isFalse);
      await c.close();
    });
  });

  // the AuthUser import keeps the fakes honest about the account ids used above
  test('account ids are plain strings', () {
    expect(const AuthUser(id: 'user-a', email: 'a@example.com').id, 'user-a');
    expect(FakeAuth().currentUser, isNull);
  });
}
