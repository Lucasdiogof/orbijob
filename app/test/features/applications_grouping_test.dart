import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/applications/applications_page.dart';
import 'package:orbijob/features/applications/domain/application_record.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/l10n/app_localizations.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');

ApplicationRecord _app(String id, ApplicationStage st) => ApplicationRecord(
  id: id,
  stage: st,
  job: JobPosting(
    source: 'manual',
    externalId: id,
    company: 'Company $id',
    title: 'Role $id',
    originalUrl: '',
  ),
);

void main() {
  testWidgets(
    'all stages: one header per stage with its count, same tiles; a selected stage shows the plain list',
    (t) async {
      final auth = FakeAuth()..currentUser = _user;
      final fakes = Fakes(auth: auth);
      fakes.applications.rows.addAll([
        _app('a1', ApplicationStage.interview),
        _app('a2', ApplicationStage.interested),
        _app('a3', ApplicationStage.interested),
      ]);
      await pumpApp(t, auth: auth, fakes: fakes, size: const Size(390, 2000));
      final l = AppLocalizations.of(t.element(find.byType(Scaffold).first));
      await t.tap(find.text(l.navApplications).first);
      await t.pumpAndSettle();

      final interested = l.apPipelineCount(
        applicationStageLabel(l, ApplicationStage.interested),
        2,
      );
      final interview = l.apPipelineCount(
        applicationStageLabel(l, ApplicationStage.interview),
        1,
      );
      // the chip and the group header carry the same text (the chip row scrolls sideways, so a later chip may not be built yet)
      expect(find.text(interested), findsNWidgets(2));
      expect(find.text(interview), findsAtLeastNWidgets(1));
      for (final id in ['a1', 'a2', 'a3']) {
        expect(find.text('Role $id'), findsOneWidget);
      }
      // pipeline order: interested before interview
      expect(
        t.getTopLeft(find.text('Role a2')).dy,
        lessThan(t.getTopLeft(find.text('Role a1')).dy),
      );

      // selecting a stage: only its tiles, no group header (only the chip)
      await t.tap(find.text(interested).first);
      await t.pumpAndSettle();
      expect(find.text(interested), findsOneWidget);
      expect(find.text('Role a1'), findsNothing);
      expect(find.text('Role a2'), findsOneWidget);
    },
  );
}
