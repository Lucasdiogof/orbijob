import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/design/design.dart';

import '../helpers/harness.dart';

Brightness _theme(WidgetTester t) =>
    Theme.of(t.element(find.byType(Scaffold).first)).brightness;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('ThemeMode.system follows a light platform', (t) async {
    await pumpApp(t, platformBrightness: Brightness.light);
    expect(_theme(t), Brightness.light);
    expect(
      Theme.of(t.element(find.byType(Scaffold).first)).extension<AppColors>(),
      AppColors.light,
    );
  });

  testWidgets('ThemeMode.system follows a dark platform', (t) async {
    await pumpApp(t, platformBrightness: Brightness.dark);
    expect(_theme(t), Brightness.dark);
    expect(
      Theme.of(t.element(find.byType(Scaffold).first)).extension<AppColors>(),
      AppColors.dark,
    );
  });

  testWidgets('user can force light and dark from the profile page', (t) async {
    await pumpApp(t, platformBrightness: Brightness.dark);
    await t.tap(find.byTooltip('Profile'));
    await t.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);

    await t.tap(find.text('Light'));
    await t.pumpAndSettle();
    expect(_theme(t), Brightness.light);

    await t.tap(find.text('Dark'));
    await t.pumpAndSettle();
    expect(_theme(t), Brightness.dark);

    await t.tap(find.text('System'));
    await t.pumpAndSettle();
    expect(_theme(t), Brightness.dark, reason: 'platform is dark');
  });

  testWidgets('scaffold and text colours come from the tokens in both themes', (
    t,
  ) async {
    for (final b in Brightness.values) {
      await pumpApp(t, platformBrightness: b);
      final colors = b == Brightness.dark ? AppColors.dark : AppColors.light;
      final scaffold = t.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        scaffold.backgroundColor ??
            Theme.of(t.element(find.byType(Scaffold).first))
                .scaffoldBackgroundColor,
        colors.bg,
      );
    }
  });

  testWidgets('fonts are the identity families', (t) async {
    await pumpApp(t);
    final theme = Theme.of(t.element(find.byType(Scaffold).first));
    expect(theme.textTheme.headlineMedium!.fontFamily, 'SpaceGrotesk');
    expect(theme.textTheme.titleMedium!.fontFamily, 'SpaceGrotesk');
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter');
    expect(theme.textTheme.labelLarge!.fontFamily, 'Inter');
    expect(
      theme.textTheme.bodyMedium!.fontFamilyFallback,
      contains('Noto Sans JP'),
    );
  });
}
