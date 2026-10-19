import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/design/design.dart';
import 'package:orbijob/core/orbi/orbi.dart';

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
}
