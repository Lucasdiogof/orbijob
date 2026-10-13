import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orbijob/features/compare/compare_cubit.dart';
import 'package:orbijob/features/compare/compare_page.dart';
import 'package:orbijob/features/jobs/job_actions_menu.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/l10n/app_localizations_en.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');
final _en = AppLocalizationsEn();

JobPosting _job(
  String id,
  String title, {
  String company = 'Acme',
  String? country,
  String? city,
  WorkMode mode = WorkMode.unspecified,
  double? min,
  double? max,
  String? currency,
  SalaryPeriod? period,
  List<String> geo = const [],
  String? language,
  String url = 'https://example.com/job',
  String? contract,
}) => JobPosting(
  source: 'jobicy',
  externalId: id,
  company: company,
  title: title,
  originalUrl: url,
  country: country,
  city: city,
  workMode: mode,
  salaryMin: min,
  salaryMax: max,
  salaryCurrency: currency,
  salaryPeriod: period,
  geoRestrictions: geo,
  language: language,
  contractType: contract,
  sourceName: 'Jobicy',
  publishedAt: DateTime.utc(2026, 10, 10),
);

void main() {
  group('CompareCubit', () {
    test('adds up to three in the order picked, toggles, refuses a fourth without replacing', () {
      final c = CompareCubit();
      final a = _job('1', 'A'),
          b = _job('2', 'B'),
          d = _job('3', 'C'),
          e = _job('4', 'D');
      expect(c.toggle(a), CompareChange.added);
      expect(c.toggle(b), CompareChange.added);
      expect(c.toggle(d), CompareChange.added);
      expect(c.toggle(e), CompareChange.full);
      expect(c.state.map((j) => j.externalId), ['1', '2', '3']);
      expect(c.toggle(b), CompareChange.removed);
      expect(c.state.map((j) => j.externalId), ['1', '3']);
      expect(c.contains(a), isTrue);
      expect(c.contains(b), isFalse);
      c.clear();
      expect(c.state, isEmpty);
    });
  });

  group('comparisonRows: only what the listings state', () {
    test(
      'missing values stay missing: no salary, mode or language is invented',
      () {
        final rows = comparisonRows(
          [
            _job(
              '1',
              'Nurse',
              country: 'DE',
              mode: WorkMode.remote,
              min: 3000,
              max: 4000,
              currency: 'EUR',
              period: SalaryPeriod.month,
              language: 'de',
            ),
            _job('2', 'Nurse'),
          ],
          _en,
          now: DateTime.utc(2026, 10, 13),
        );
        Map<String, List<String?>> by = {
          for (final r in rows) r.label: r.values,
        };
        expect(by['Work mode'], ['Remote', null]);
        expect(by['Salary']![1], isNull);
        expect(by['Salary']![0], contains('3,000'));
        expect(by['Listing language'], ['Deutsch', null]);
        expect(by['Location']![1], isNull);
        expect(by['Contract'], [null, null]);
        expect(by['Who can apply'], [
          null,
          null,
        ], reason: 'a location is not a statement of who may apply');
      },
    );

    test('who can apply: only the explicit restriction list; "Anywhere" is said as the source states it', () {
      final rows = comparisonRows([
        _job('1', 'A', geo: ['Anywhere']),
        _job('2', 'B', geo: ['BR', 'PT']),
        _job('3', 'C', country: 'DE'),
        _job('4', 'D', geo: ['EMEA']),
      ], _en);
      final v = rows.firstWhere((r) => r.label == 'Who can apply').values;
      expect(v[0], 'Anywhere (as the source states)');
      expect(v[1], 'Limited to: Brazil, Portugal');
      expect(v[2], isNull);
      expect(v[3], contains('Limited to:'));
    });

    test(
      'rows that differ are marked, identical or all-missing ones are not',
      () {
        final rows = comparisonRows([
          _job('1', 'A', company: 'Acme'),
          _job('2', 'B', company: 'Beta'),
        ], _en);
        expect(rows.firstWhere((r) => r.label == 'Company').differs, isTrue);
        expect(rows.firstWhere((r) => r.label == 'Contract').differs, isFalse);
        final same = comparisonRows([
          _job('1', 'A', contract: 'Full-time'),
          _job('2', 'B', contract: 'Full-time'),
        ], _en);
        expect(same.firstWhere((r) => r.label == 'Contract').differs, isFalse);
        final half = comparisonRows([
          _job('1', 'A', contract: 'Full-time'),
          _job('2', 'B'),
        ], _en);
        expect(half.firstWhere((r) => r.label == 'Contract').differs, isTrue);
      },
    );

    test('salaries in different currencies or periods are flagged as not converted', () {
      expect(
        salariesNotComparable([
          _job('1', 'A', min: 1, currency: 'EUR', period: SalaryPeriod.month),
          _job('2', 'B', min: 1, currency: 'USD', period: SalaryPeriod.month),
        ]),
        isTrue,
      );
      expect(
        salariesNotComparable([
          _job('1', 'A', min: 1, currency: 'EUR', period: SalaryPeriod.month),
          _job('2', 'B', max: 2, currency: 'EUR', period: SalaryPeriod.month),
        ]),
        isFalse,
      );
      expect(
        salariesNotComparable([
          _job('1', 'A', min: 1, currency: 'EUR', period: SalaryPeriod.month),
          _job('2', 'B'),
        ]),
        isFalse,
      );
    });
  });

  group('share text', () {
    test('title, company and the listing\'s own link; nothing else', () {
      expect(
        shareTextFor(
          _job('1', 'Welder', company: 'Acme', url: 'https://example.com/j/1'),
        ),
        'Welder — Acme\nhttps://example.com/j/1',
      );
      expect(
        shareTextFor(
          _job('1', 'Welder', company: '', url: 'https://example.com/j/1'),
        ),
        'Welder\nhttps://example.com/j/1',
      );
    });

    test('no web link, nothing to share', () {
      expect(shareTextFor(_job('1', 'Welder', url: '')), isNull);
      expect(
        shareTextFor(_job('1', 'Welder', url: 'javascript:alert(1)')),
        isNull,
      );
      expect(shareTextFor(_job('1', 'Welder', url: 'ftp://x/y')), isNull);
      expect(shareTextFor(_job('1', 'Welder', url: '/relative')), isNull);
    });
  });

  group('on screen', () {
    Future<void> search(WidgetTester t, String term) async {
      await t.tap(find.text('Explore'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), term);
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
    }

    testWidgets(
      'share sends the title and the listing link through the platform share',
      (t) async {
        final shared = <String>[];
        final auth = FakeAuth()..currentUser = _user;
        await pumpApp(
          t,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: Fakes(auth: auth),
          textShare: (text, {subject}) async => shared.add('$subject|$text'),
          size: const Size(390, 1000),
        );
        await search(t, 'Pedreiro');
        await t.tap(find.byTooltip('More actions for Pedreiro'));
        await t.pumpAndSettle();
        await t.tap(find.text('Share this job'));
        await t.pumpAndSettle();
        expect(shared.single, startsWith('Pedreiro|Pedreiro — '));
        expect(shared.single, contains('https://'));
      },
    );

    testWidgets(
      'where sharing is unavailable the text is copied and the person is told',
      (t) async {
        final auth = FakeAuth()..currentUser = _user;
        await pumpApp(
          t,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: Fakes(auth: auth),
          textShare: (text, {subject}) async => throw UnimplementedError(),
          size: const Size(390, 1000),
        );
        String? clip;
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clip = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await search(t, 'Pedreiro');
        await t.tap(find.byTooltip('More actions for Pedreiro'));
        await t.pumpAndSettle();
        await t.tap(find.text('Share this job'));
        await t.pumpAndSettle();
        expect(clip, contains('Pedreiro'));
        expect(find.textContaining('Link copied'), findsOneWidget);
      },
    );

    testWidgets(
      'pick two jobs, compare them side by side on a wide window, drop one and the page asks for a second',
      (t) async {
        final auth = FakeAuth()..currentUser = _user;
        await pumpApp(
          t,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: Fakes(auth: auth),
          size: const Size(1300, 1000),
        );
        await t.tap(find.text('Explore'));
        await t.pumpAndSettle();
        // empty search lists every preview job; add the first two cards to the comparison
        final menus = find.byIcon(Icons.more_vert_rounded);
        expect(menus, findsAtLeastNWidgets(2));
        for (var i = 0; i < 2; i++) {
          await t.tap(find.byIcon(Icons.more_vert_rounded).at(i));
          await t.pumpAndSettle();
          await t.tap(find.text('Add to comparison'));
          await t.pumpAndSettle();
        }
        expect(find.text('2 jobs picked'), findsOneWidget);
        await t.tap(find.text('Compare').last);
        await t.pumpAndSettle();
        expect(find.text('Compare jobs'), findsOneWidget);
        expect(find.text('Company'), findsOneWidget);
        expect(find.text('Who can apply'), findsOneWidget);
        expect(find.textContaining('Nothing is estimated'), findsOneWidget);
        expect(find.text('Not stated'), findsWidgets);
        expect(t.takeException(), isNull);
        await t.tap(find.byIcon(Icons.close_rounded).first);
        await t.pumpAndSettle();
        expect(find.textContaining('Pick at least two jobs'), findsOneWidget);
      },
    );

    testWidgets(
      'on a phone the comparison is one block per attribute, with no sideways scroll or overflow',
      (t) async {
        final auth = FakeAuth()..currentUser = _user;
        await pumpApp(
          t,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: Fakes(auth: auth),
          size: const Size(360, 1500),
          textScale: 1.3,
        );
        await t.tap(find.text('Explore'));
        await t.pumpAndSettle();
        // three jobs are already picked; a fourth from the menu does not fit and says so
        final cubit = t.element(find.byType(CompareBar)).read<CompareCubit>();
        for (final n in ['x1', 'x2', 'x3']) {
          cubit.toggle(
            _job(n, 'Picked $n', country: 'DE', mode: WorkMode.remote),
          );
        }
        await t.pumpAndSettle();
        await t.tap(find.byIcon(Icons.more_vert_rounded).first);
        await t.pumpAndSettle();
        await t.tap(find.text('Add to comparison'));
        await t.pumpAndSettle();
        expect(find.textContaining('up to 3 jobs'), findsOneWidget);
        expect(cubit.state.length, 3);
        await t.pump(const Duration(seconds: 8));
        await t.tap(find.text('Compare').last);
        await t.pumpAndSettle();
        expect(find.text('Company'), findsOneWidget);
        expect(find.text('1. Picked x1'), findsOneWidget);
        expect(find.text('3. Picked x3'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  });
}
