import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/design/design.dart';
import 'package:orbijob/core/widgets/app_button.dart';
import 'package:orbijob/core/widgets/app_filter_chip.dart';
import 'package:orbijob/core/widgets/compatibility_indicator.dart';
import 'package:orbijob/core/widgets/skeleton.dart';
import 'package:orbijob/core/widgets/state_view.dart';
import 'package:orbijob/core/widgets/status_badge.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/presentation/widgets/job_card.dart';
import 'package:orbijob/l10n/app_localizations.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/harness.dart';

Widget host(
  Widget child, {
  Brightness b = Brightness.light,
  double width = 360,
}) => MaterialApp(
  theme: b == Brightness.light ? AppTheme.light() : AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadBrandFonts();
  });

  testWidgets(
    'JobCard draws only what the source provides (no invented salary, date, place or match)',
    (t) async {
      const bare = ScoredJob(
        JobPosting(
          source: 's',
          externalId: '1',
          company: 'ACME',
          title: 'Operator',
          originalUrl: 'https://e.invalid',
        ),
      );
      await t.pumpWidget(host(const JobCard(scored: bare)));
      expect(find.text('Operator'), findsOneWidget);
      expect(find.text('ACME'), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsNothing);
      expect(find.textContaining('Posted'), findsNothing);
      expect(find.byType(CompatibilityIndicator), findsNothing);
      expect(find.textContaining('Source:'), findsNothing);
      expect(
        find.byIcon(Icons.favorite_border),
        findsNothing,
        reason: 'no favourite callback, no button',
      );
    },
  );

  testWidgets(
    'JobCard shows full hierarchy when data exists, compatibility and confidence separately',
    (t) async {
      await t.pumpWidget(
        host(
          JobCard(
            scored: previewJobs[1],
            now: previewNow,
            onFavoriteChanged: (_) {},
          ),
        ),
      );
      for (final s in [
        'Fisioterapeuta pélvica',
        'Clínica Exemplo',
        'Berlim · DE',
        'On-site',
        'Posted yesterday',
        'EUR',
        '81',
        'Medium confidence',
        'Source: Fonte de exemplo',
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.textContaining('3,400–4,100/month'), findsOneWidget);
      expect(find.byType(CompatibilityIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'long titles wrap (never truncated) at 200% text in a narrow card',
    (t) async {
      const long = ScoredJob(
        JobPosting(
          source: 's',
          externalId: '1',
          company: 'Empresa de Engenharia e Serviços Gerais Exemplo',
          title: 'Técnico de Manutenção Industrial Eletromecânica Sênior',
          originalUrl: 'https://e.invalid',
        ),
      );
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.platformDispatcher.clearAllTestValues);
      await t.pumpWidget(host(const JobCard(scored: long), width: 280));
      expect(t.takeException(), isNull);
      final title = t.widget<Text>(
        find.text('Técnico de Manutenção Industrial Eletromecânica Sênior'),
      );
      expect(title.overflow, isNull);
      expect(title.maxLines, isNull);
    },
  );

  testWidgets(
    'filter chip: selection uses a check icon, not colour alone; toggles on tap',
    (t) async {
      var on = false;
      await t.pumpWidget(
        host(
          StatefulBuilder(
            builder: (c, set) => AppFilterChip(
              label: 'Health',
              selected: on,
              onSelected: (v) => set(() => on = v),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.check), findsNothing);
      await t.tap(find.text('Health'));
      await t.pumpAndSettle();
      expect(on, isTrue);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        t.getSize(find.byType(AppFilterChip)).height,
        greaterThanOrEqualTo(48),
      );
    },
  );

  testWidgets('buttons: min 48 dp, loading disables, disabled does not fire', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(label: 'Go', onPressed: () => taps++),
            AppButton(label: 'Busy', loading: true, onPressed: () => taps++),
            const AppButton(label: 'Off', onPressed: null),
            AppButton(
              label: 'Second',
              variant: AppButtonVariant.secondary,
              onPressed: () => taps++,
            ),
            AppButton(
              label: 'Third',
              variant: AppButtonVariant.tertiary,
              onPressed: () => taps++,
            ),
          ],
        ),
      ),
    );
    for (final b in t.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    )) {
      expect(t.getSize(find.byWidget(b)).height, greaterThanOrEqualTo(48));
    }
    for (final label in ['Go', 'Busy', 'Off', 'Second', 'Third']) {
      await t.tap(find.text(label), warnIfMissed: false);
    }
    expect(taps, 3);
  });

  testWidgets(
    'compatibility ring grows with text scale so the number always fits',
    (t) async {
      Widget ring() => host(
        const Align(
          alignment: Alignment.topLeft,
          child: CompatibilityIndicator(score: 100),
        ),
      );
      await t.pumpWidget(ring());
      final base = t.getSize(find.byType(CompatibilityIndicator)).width;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.platformDispatcher.clearAllTestValues);
      await t.pumpWidget(ring());
      await t.pump();
      expect(
        t.getSize(find.byType(CompatibilityIndicator)).width,
        greaterThan(base),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('status badge pairs text with icon (meaning not colour-only)', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        const StatusBadge(
          label: 'Remote',
          kind: BadgeKind.success,
          icon: Icons.public,
        ),
      ),
    );
    expect(find.text('Remote'), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });

  testWidgets(
    'state view scrolls instead of overflowing in a very short window',
    (t) async {
      await t.pumpWidget(
        host(
          const SizedBox(
            height: 120,
            child: StateView(
              icon: Icons.search_off,
              title: 'No jobs found',
              body: 'Try another profession or a broader search.',
              action: AppButton(label: 'Retry', onPressed: null),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('skeleton pulses normally and holds still with reduced motion', (
    t,
  ) async {
    await t.pumpWidget(host(const SkeletonList()));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.binding.hasScheduledFrame, isTrue);
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.pumpWidget(host(const SkeletonList()));
    await t.pumpAndSettle();
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('brand logo and symbol render in light and dark', (t) async {
    for (final b in Brightness.values) {
      await t.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [BrandLogo(height: 32), BrandSymbol(size: 48)],
          ),
          b: b,
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.bySemanticsLabel('OrbiJob'), findsWidgets);
    }
  });
}
