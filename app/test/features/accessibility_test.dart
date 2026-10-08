import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/harness.dart';

Future<void> goExplore(WidgetTester t, String q) async {
  await t.tap(find.bySemanticsLabel('Explore').first);
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField).last, q);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadBrandFonts();
  });

  for (final b in Brightness.values) {
    group('guidelines (${b.name})', () {
      testWidgets('home: tap targets, labels, contrast', (t) async {
        final h = t.ensureSemantics();
        await pumpApp(t, platformBrightness: b);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });

      testWidgets('results with cards: tap targets, labels, contrast', (
        t,
      ) async {
        final h = t.ensureSemantics();
        await pumpApp(
          t,
          platformBrightness: b,
          repo: PreviewSearchRepository(),
        );
        await goExplore(t, 'Pedreiro');
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });

      testWidgets('states: no source and favorites empty', (t) async {
        final h = t.ensureSemantics();
        await pumpApp(t, platformBrightness: b);
        await t.tap(find.bySemanticsLabel('Explore').first);
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField).last, 'x');
        await t.testTextInput.receiveAction(TextInputAction.search);
        await t.pumpAndSettle();
        await expectLater(t, meetsGuideline(textContrastGuideline));
        await t.tap(find.bySemanticsLabel('Favorites').first);
        await t.pumpAndSettle();
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    });
  }

  testWidgets(
    'navigation items are announced as selected buttons with full labels',
    (t) async {
      final h = t.ensureSemantics();
      await pumpApp(t);
      final node = t.getSemantics(find.bySemanticsLabel('Home').first);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      final other = t.getSemantics(find.bySemanticsLabel('Explore').first);
      expect(other.flagsCollection.isSelected, isNot(Tristate.isTrue));
      h.dispose();
    },
  );

  testWidgets(
    'compatibility and confidence are announced as separate, complete sentences',
    (t) async {
      final h = t.ensureSemantics();
      await pumpApp(t, repo: PreviewSearchRepository());
      await goExplore(t, 'Pedreiro');
      expect(
        find.bySemanticsLabel('Compatibility 74 out of 100'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Analysis confidence: Medium confidence'),
        findsOneWidget,
      );
      h.dispose();
    },
  );

  testWidgets('favourite button is a toggle with a state-specific label', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await pumpApp(t, repo: PreviewSearchRepository());
    await goExplore(t, 'Pedreiro');
    final off = t.getSemantics(find.bySemanticsLabel('Save job').first);
    expect(off.flagsCollection.isToggled, isNot(Tristate.none));
    expect(off.flagsCollection.isToggled, Tristate.isFalse);
    await t.tap(find.bySemanticsLabel('Save job').first);
    await t.pumpAndSettle();
    final on = t.getSemantics(
      find.bySemanticsLabel('Remove from favorites').first,
    );
    expect(on.flagsCollection.isToggled, Tristate.isTrue);
    h.dispose();
  });

  testWidgets('keyboard focus is visible (outline) when navigating with Tab', (
    t,
  ) async {
    await pumpApp(t, size: const Size(1280, 800));
    expect(
      find.byKey(const ValueKey('focus-ring-active')),
      findsNothing,
      reason: 'no ring before keyboard use',
    );
    var seen = false;
    for (var i = 0; i < 12 && !seen; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      seen = find
          .byKey(const ValueKey('focus-ring-active'))
          .evaluate()
          .isNotEmpty;
    }
    expect(seen, isTrue, reason: 'a focused control must draw the 2px outline');
  });

  testWidgets('reduced motion: skeletons stay still and the app settles', (
    t,
  ) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(t);
    await t.pumpAndSettle();
    expect(t.binding.hasScheduledFrame, isFalse);
  });
}
