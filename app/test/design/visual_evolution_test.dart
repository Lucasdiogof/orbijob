import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/design/design.dart';
import 'package:orbijob/core/orbi/orbi.dart';
import 'package:orbijob/features/profile/presentation/widgets/profile_completeness.dart';
import 'package:orbijob/l10n/app_localizations.dart';

Widget _host(Widget child, {bool reduce = false, bool dark = false}) =>
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('OrbiMonogram', () {
    test('takes the first letter or digit, ignoring symbols and spaces', () {
      expect(OrbiMonogram.initialOf('  acme corp'), 'A');
      expect(OrbiMonogram.initialOf('"Éclair" SA'), 'É');
      expect(OrbiMonogram.initialOf('42 Labs'), '4');
      expect(OrbiMonogram.initialOf('—'), isNull);
      expect(OrbiMonogram.initialOf(''), isNull);
    });

    testWidgets('is hidden from screen readers and stable per name', (t) async {
      await t.pumpWidget(_host(const OrbiMonogram(name: 'Construtora')));
      expect(find.text('C'), findsOneWidget);
      final h = t.ensureSemantics();
      expect(find.bySemanticsLabel('C'), findsNothing);
      h.dispose();
    });

    testWidgets('draws nothing for a name without letters', (t) async {
      await t.pumpWidget(_host(const OrbiMonogram(name: '—')));
      expect(find.byType(Text), findsNothing);
    });
  });

  group('motion', () {
    testWidgets('Reveal fades the child in and settles fully visible', (
      t,
    ) async {
      await t.pumpWidget(_host(const Reveal(index: 2, child: Text('hello'))));
      final first = t.widget<Opacity>(find.byType(Opacity).first).opacity;
      expect(first, lessThan(1));
      await t.pumpAndSettle();
      expect(t.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
    });

    testWidgets('Reveal does nothing with reduced motion', (t) async {
      await t.pumpWidget(
        _host(const Reveal(child: Text('hello')), reduce: true),
      );
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('Pressable shrinks while pressed and not when reduced', (
      t,
    ) async {
      await t.pumpWidget(
        _host(const Pressable(child: SizedBox(width: 80, height: 40))),
      );
      final g = await t.startGesture(t.getCenter(find.byType(SizedBox).last));
      await t.pump(AppMotion.base);
      expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0.98);
      await g.up();
      await t.pumpAndSettle();
      expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);

      await t.pumpWidget(
        _host(
          const Pressable(child: SizedBox(width: 80, height: 40)),
          reduce: true,
        ),
      );
      expect(find.byType(AnimatedScale), findsNothing);
    });
  });

  group('surfaces keep the text contrast', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final (name, c) in [
      ('light', AppColors.light),
      ('dark', AppColors.dark),
    ]) {
      test(
        '$name: ink on both ends of the card gradient and on-primary on the button gradient',
        () {
          final card = (c.cardGradient as LinearGradient).colors;
          for (final end in card) {
            expect(ratio(c.ink, end), greaterThanOrEqualTo(4.5));
            expect(ratio(c.muted, end), greaterThanOrEqualTo(4.5));
          }
          final button = (c.primaryGradient as LinearGradient).colors;
          for (final end in button) {
            expect(ratio(c.onPrimary, end), greaterThanOrEqualTo(4.5));
          }
        },
      );
    }
  });

  group('OrbiFilterChip motion', () {
    Widget chip(bool on, {bool reduce = false}) => _host(
      OrbiFilterChip(label: 'Remote', selected: on, onSelected: (_) {}),
      reduce: reduce,
    );

    testWidgets('the check grows in while the chip animates, and settles', (
      t,
    ) async {
      await t.pumpWidget(chip(false));
      expect(find.byIcon(Icons.check), findsNothing);
      await t.pumpWidget(chip(true));
      await t.pump(const Duration(milliseconds: 40));
      expect(find.byIcon(Icons.check), findsOneWidget);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('with reduced motion the check is there on the first frame', (
      t,
    ) async {
      await t.pumpWidget(chip(false, reduce: true));
      await t.pumpWidget(chip(true, reduce: true));
      await t.pump();
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('profile completeness bar', () {
    Widget card(List<String> missing, {bool reduce = false}) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(body: ProfileCompletenessCard(missing: missing)),
      ),
    );

    double value(WidgetTester t) => t
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    testWidgets('fills to the real share of parts and follows changes', (
      t,
    ) async {
      await t.pumpWidget(card(['a', 'b', 'c', 'd', 'e', 'f', 'g']));
      await t.pumpAndSettle();
      expect(value(t), 0);
      await t.pumpWidget(card(['a']));
      await t.pump(const Duration(milliseconds: 60));
      expect(value(t), lessThan(6 / 7)); // still on its way
      await t.pumpAndSettle();
      expect(value(t), closeTo(6 / 7, 0.01));
    });

    testWidgets('with reduced motion it is at its value at once', (t) async {
      await t.pumpWidget(card(['a', 'b'], reduce: true));
      await t.pump();
      expect(value(t), closeTo(5 / 7, 0.01));
    });
  });
}
