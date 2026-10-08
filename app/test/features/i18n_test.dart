import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/harness.dart';

Map<String, dynamic> arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadBrandFonts();
  });

  test('pt, en and es define exactly the same messages', () {
    final en = arb('en').keys.where((k) => !k.startsWith('@')).toSet();
    for (final l in ['pt', 'es']) {
      expect(
        arb(l).keys.where((k) => !k.startsWith('@')).toSet(),
        en,
        reason: l,
      );
    }
  });

  test('translated messages keep the same placeholders', () {
    final re = RegExp(r'\{(\w+)(?:,|\})');
    final en = arb('en');
    for (final k in en.keys.where((k) => !k.startsWith('@'))) {
      final p = re.allMatches(en[k] as String).map((m) => m.group(1)).toSet();
      for (final l in ['pt', 'es']) {
        expect(
          re.allMatches(arb(l)[k] as String).map((m) => m.group(1)).toSet(),
          p,
          reason: '$l.$k',
        );
      }
    }
  });

  test(
    'no user-facing string literals in widgets (all text goes through l10n)',
    () {
      final offenders = <String>[];
      final literal = RegExp(r"""Text\(\s*['"][^'"$]*[A-Za-zÀ-ÿ]""");
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final p = f.path.replaceAll('\\', '/');
        if (p.contains('lib/l10n/') || p.contains('lib/preview/')) continue;
        if (literal.hasMatch(f.readAsStringSync())) offenders.add(p);
      }
      expect(offenders, isEmpty);
    },
  );

  const expectations = {
    'en': [
      'Home',
      'Explore',
      'Favorites',
      'Applications',
      'What are you looking for?',
    ],
    'pt': [
      'Início',
      'Explorar',
      'Favoritos',
      'Candidaturas',
      'O que você procura?',
    ],
    'es': [
      'Inicio',
      'Explorar',
      'Favoritos',
      'Postulaciones',
      '¿Qué estás buscando?',
    ],
  };
  for (final e in expectations.entries) {
    testWidgets('app renders in ${e.key}', (t) async {
      await pumpApp(t, locale: Locale(e.key));
      for (final s in e.value) {
        expect(find.text(s), findsWidgets, reason: '${e.key}: $s');
      }
    });
  }

  testWidgets('salary, currency code and relative date follow the locale', (
    t,
  ) async {
    for (final (loc, salary, posted) in [
      ('en', 'R\$ 9,000–12,000/month', 'Posted 3 days ago'),
      ('pt', 'R\$ 9.000–12.000/mês', 'Publicada há 3 dias'),
      ('es', 'R\$ 9.000–12.000/mes', 'Publicada hace 3 días'),
    ]) {
      await pumpApp(t, locale: Locale(loc), repo: PreviewSearchRepository());
      final explore = {
        'en': 'Explore',
        'pt': 'Explorar',
        'es': 'Explorar',
      }[loc]!;
      await t.tap(find.bySemanticsLabel(explore).first, warnIfMissed: false);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Flutter');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(
        find.textContaining(salary.split('/').first),
        findsOneWidget,
        reason: loc,
      );
      expect(find.text('BRL'), findsOneWidget);
      expect(
        find.textContaining(posted.split(' ').first),
        findsWidgets,
        reason: loc,
      );
    }
  });
}
