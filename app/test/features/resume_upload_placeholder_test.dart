import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/orbi/orbi.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/profile/domain/pdf_picker.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');

void main() {
  testWidgets(
    'while a résumé is being stored a placeholder row is shown, then it becomes the real row',
    (t) async {
      final auth = FakeAuth()..currentUser = _user;
      final fakes = Fakes(auth: auth);
      await fakes.profiles.save(const ProfessionalProfile(name: 'Maria'));
      final gate = Completer<void>();
      fakes.resumes.uploadGate = gate;
      await pumpApp(
        t,
        auth: auth,
        fakes: fakes,
        size: const Size(390, 1200),
        pdfPicker: FakePdfPicker(PickedPdf(name: 'cv.pdf', bytes: tinyPdf())),
      );
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await t.tap(find.text('Résumés'));
      await t.pumpAndSettle();
      expect(find.byType(OrbiSkeleton), findsNothing);
      expect(find.text('No résumé uploaded yet.'), findsOneWidget);

      await t.tap(find.text('Upload PDF'));
      await t.pump(const Duration(milliseconds: 100));
      // upload held open: skeleton row, the button says it is uploading, and the row is announced
      expect(find.byType(OrbiSkeleton), findsWidgets);
      expect(
        find.text('Uploading…'),
        findsNWidgets(2),
      ); // the button and the row
      // the "nothing yet" message is not shown while the first file is on its way
      expect(find.text('No résumé uploaded yet.'), findsNothing);
      expect(find.bySemanticsLabel('Uploading…'), findsWidgets);
      expect(fakes.resumes.rows, isEmpty);

      gate.complete();
      await t.pumpAndSettle();
      expect(find.byType(OrbiSkeleton), findsNothing);
      expect(fakes.resumes.rows, hasLength(1));
    },
  );
}
