import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/harness.dart';

class _Throwing implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? countryCode}) async =>
      throw Exception('x');
}

class _Empty implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? countryCode}) async =>
      const SearchResult(jobs: [], hasIntegratedSource: true);
}

class _Never implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? countryCode}) =>
      Completer<SearchResult>().future;
}

const sizes = <String, Size>{
  'phone-small 320x568': Size(320, 568),
  'phone 360x640': Size(360, 640),
  'phone 390x844': Size(390, 844),
  'phone-large 412x915': Size(412, 915),
  'tablet-portrait 800x1000': Size(800, 1000),
  'tablet-landscape 1024x768': Size(1024, 768),
  'desktop 1280x800': Size(1280, 800),
  'phone-landscape 844x390': Size(844, 390),
};

Future<void> search(WidgetTester t, String q) async {
  await t.enterText(find.byType(TextField).last, q);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pump();
}

/// Visits every screen/state; returns descriptions of anything that threw (overflow, layout errors).
Future<List<String>> visitAll(
  WidgetTester t,
  String tag, {
  required Locale locale,
}) async {
  final problems = <String>[];

  Future<void> settle(String where) async {
    await t.pumpAndSettle();
    final e = t.takeException();
    if (e != null) {
      problems.add('$tag @ $where: ${e.toString().split('\n').first}');
    }
  }

  Future<void> tapTab(int i) async {
    const names = {
      'en': ['Home', 'Explore', 'Favorites', 'Applications'],
      'pt': ['Início', 'Explorar', 'Favoritos', 'Candidaturas'],
      'es': ['Inicio', 'Explorar', 'Favoritos', 'Postulaciones'],
    };
    await t.tap(
      find.bySemanticsLabel(names[locale.languageCode]![i]).first,
      warnIfMissed: false,
    );
  }

  await settle('home');
  await tapTab(2);
  await settle('favorites');
  await tapTab(3);
  await settle('applications');
  await tapTab(1);
  await settle('explore-idle');
  await search(t, 'Pedreiro');
  await settle('explore-results');
  return problems;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadBrandFonts();
  });

  group('no overflow: sizes x text scale x themes (en)', () {
    for (final e in sizes.entries) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('${e.key} text ${(scale * 100).round()}%', (t) async {
          final problems = <String>[];
          for (final b in Brightness.values) {
            await pumpApp(
              t,
              size: e.value,
              textScale: scale,
              platformBrightness: b,
              repo: PreviewSearchRepository(),
            );
            problems.addAll(
              await visitAll(
                t,
                '${e.key} x$scale ${b.name}',
                locale: const Locale('en'),
              ),
            );
          }
          expect(problems, isEmpty);
        });
      }
    }
  });

  group('no overflow: translations take more room (pt/es, 200%)', () {
    for (final loc in [const Locale('pt'), const Locale('es')]) {
      for (final size in [
        const Size(320, 568),
        const Size(390, 844),
        const Size(1280, 800),
      ]) {
        testWidgets(
          '${loc.languageCode} ${size.width.toInt()}x${size.height.toInt()}',
          (t) async {
            await pumpApp(
              t,
              size: size,
              textScale: 2,
              locale: loc,
              repo: PreviewSearchRepository(),
            );
            final problems = await visitAll(
              t,
              '${loc.languageCode} $size',
              locale: loc,
            );
            expect(problems, isEmpty);
          },
        );
      }
    }
  });

  group('states: loading, empty, error, no source (narrow, 200% text)', () {
    final repos = <String, SearchRepository>{
      'loading': _Never(),
      'empty': _Empty(),
      'error': _Throwing(),
      'nosource': NoSourceSearchRepository(),
    };
    for (final r in repos.entries) {
      for (final size in [const Size(320, 568), const Size(1280, 800)]) {
        testWidgets('${r.key} ${size.width.toInt()}', (t) async {
          await pumpApp(t, size: size, textScale: 2, repo: r.value);
          await t.tap(
            find.bySemanticsLabel('Explore').first,
            warnIfMissed: false,
          );
          await t.pumpAndSettle();
          await search(t, 'x');
          if (r.key == 'loading') {
            await t.pump(const Duration(milliseconds: 300));
            expect(find.bySemanticsLabel('Searching…'), findsOneWidget);
          } else {
            await t.pumpAndSettle();
          }
          expect(t.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('keyboard open (viewInsets) does not overflow Explore', (
    t,
  ) async {
    await pumpApp(
      t,
      size: const Size(390, 844),
      repo: PreviewSearchRepository(),
    );
    await t.tap(find.bySemanticsLabel('Explore').first, warnIfMissed: false);
    await t.pumpAndSettle();
    t.view.viewInsets = const FakeViewPadding(bottom: 420);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    await search(t, 'Pedreiro');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('safe areas (notch and home indicator) are respected', (t) async {
    await pumpApp(
      t,
      size: const Size(390, 844),
      repo: PreviewSearchRepository(),
    );
    t.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    t.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(() {
      t.view.resetPadding();
      t.view.resetViewPadding();
    });
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    // bottom bar sits above the home indicator
    final bar = t.getBottomLeft(find.byType(SafeArea).last);
    expect(bar.dy, lessThanOrEqualTo(844));
  });
}
