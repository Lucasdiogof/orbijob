// Visual-evolution audit: with the system "reduce motion" setting on, the screens that gained entrance/state motion must show
// their content at once, run no animation, and not overflow on the smallest supported phone (320 x 568) at doubled text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/l10n/app_localizations.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');

AppLocalizations _l(WidgetTester t) =>
    AppLocalizations.of(t.element(find.byType(Scaffold).first));

void main() {
  for (final locale in const ['en', 'pt', 'es']) {
    for (final scene in const ['favorites', 'applications', 'profile hub']) {
      testWidgets('$locale · reduced motion · 320 px · text x2 · $scene', (
        t,
      ) async {
        t.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        final auth = FakeAuth()..currentUser = _user;
        await pumpApp(
          t,
          size: const Size(320, 568),
          textScale: 2,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: Fakes(auth: auth),
          locale: Locale(locale),
        );
        final l = _l(t);
        switch (scene) {
          case 'favorites':
            await t.tap(find.text(l.navFavorites).first);
          case 'applications':
            await t.tap(find.text(l.navApplications).first);
          default:
            await t.tap(find.byTooltip(l.profile));
        }
        // first frames after opening: entrance reveals are skipped, so nothing is half-transparent
        await t.pump(const Duration(milliseconds: 16));
        await t.pump(const Duration(milliseconds: 50));
        final fading = t
            .widgetList<Opacity>(find.byType(Opacity))
            .where((o) => o.opacity > 0 && o.opacity < 1);
        expect(fading, isEmpty);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'overflow or error');
      });
    }
  }
}
