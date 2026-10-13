import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/profile/domain/pdf_picker.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');

Uint8List _fixture(String name) =>
    File('test/fixtures/resumes/$name').readAsBytesSync();

/// A PDF whose only page is an image: no text layer, like a scan.
Uint8List _scan() => Uint8List.fromList(
  ('%PDF-1.4\n'
          '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'
          '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n'
          '3 0 obj\n<< /Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /XObject << /Im0 5 0 R >> >> >>\nendobj\n'
          '4 0 obj\n<< /Length 30 >>\nstream\nq 595 0 0 842 0 0 cm /Im0 Do Q\nendstream\nendobj\n'
          '5 0 obj\n<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /Length 1 >>\nstream\nx\nendstream\nendobj\n'
          '%%EOF')
      .codeUnits,
);

Future<void> _openResumes(WidgetTester t) async {
  await t.tap(find.byTooltip('Profile'));
  await t.pumpAndSettle();
  await t.tap(find.text('Résumés'));
  await t.pumpAndSettle();
}

/// Lets the real (threaded) extraction finish without freezing the test clock.
Future<void> _wait(WidgetTester t, [int ms = 700]) async {
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await t.pumpAndSettle();
}

Future<void> _upload(WidgetTester t) async {
  await t.tap(find.text('Upload PDF'));
  await t.pumpAndSettle();
  await t.tap(find.text('Review suggestions'));
  await _wait(t);
}

Future<(FakeAuth, Fakes)> _signedIn({bool withProfile = true}) async {
  final auth = FakeAuth()..currentUser = _user;
  final fakes = Fakes(auth: auth);
  if (withProfile) {
    await fakes.profiles.save(const ProfessionalProfile(name: 'Maria'));
  }
  return (auth, fakes);
}

void main() {
  testWidgets(
    'a real PDF is read on the device and the suggestions are applied only where ticked',
    (t) async {
      final (auth, fakes) = await _signedIn();
      await pumpApp(
        t,
        auth: auth,
        fakes: fakes,
        size: const Size(430, 4000),
        pdfPicker: FakePdfPicker(
          PickedPdf(name: 'cv.pdf', bytes: _fixture('cv_pt.pdf')),
        ),
      );
      await _openResumes(t);
      await _upload(t);

      // the review screen shows what was read, and what each suggestion would replace
      expect(find.text('Review suggestions'), findsWidgets);
      expect(find.textContaining('Replaces: Maria'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Clínica Vida Plena'),
        findsOneWidget,
      );

      // apply: the name is NOT ticked (existing data), so it stays
      await t.tap(find.textContaining('Apply'));
      await _wait(t, 100);
      final p = fakes.profiles.profileRows.single;
      expect(
        p.name,
        'Maria',
        reason: 'an existing value is only replaced when the user ticks it',
      );
      expect(p.headline, 'Fisioterapeuta pélvica');
      expect(p.contactEmail, 'maria.souza@example.com');
      expect(p.phone, '+55 11 91234-5678');
      expect(p.countryOfResidence, 'BR');
      expect(p.skills, containsAll(['Biofeedback', 'Pilates clínico']));
      expect(p.languages.map((l) => l.code), ['pt', 'en', 'es']);
      expect(
        fakes.profiles.expRows.map((e) => e.company),
        unorderedEquals(['Clínica Vida Plena', 'Hospital São Lucas']),
      );
      expect(
        fakes.profiles.expRows
            .firstWhere((e) => e.company == 'Clínica Vida Plena')
            .endDate,
        isNull,
      );
      expect(
        fakes.profiles.eduRows.single.institution,
        'Universidade de São Paulo',
      );
    },
  );

  testWidgets(
    'ticking the name replaces it; importing the same résumé again never duplicates entries',
    (t) async {
      final (auth, fakes) = await _signedIn();
      await pumpApp(
        t,
        auth: auth,
        fakes: fakes,
        size: const Size(430, 4000),
        pdfPicker: FakePdfPicker(
          PickedPdf(name: 'cv.pdf', bytes: _fixture('cv_pt.pdf')),
        ),
      );
      await _openResumes(t);
      await _upload(t);
      await t.tap(find.byType(Checkbox).first); // the name
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Apply'));
      await _wait(t, 100);
      expect(fakes.profiles.profileRows.single.name, 'Maria Souza');
      expect(fakes.profiles.expRows, hasLength(2));

      // the same résumé again, from the file's menu: everything is already there
      fakes.resumes.contents[fakes.resumes.rows.first.id] = _fixture(
        'cv_pt.pdf',
      );
      await t.tap(find.byTooltip('More actions'));
      await t.pumpAndSettle();
      await t.tap(find.text('Fill my profile from this résumé'));
      await _wait(t);
      expect(
        find.text('Already in your profile'),
        findsNWidgets(3),
        reason: '2 jobs + 1 degree',
      );
      expect(find.textContaining('Apply 0'), findsOneWidget);
    },
  );

  testWidgets('a scanned PDF says so honestly and opens no review screen', (
    t,
  ) async {
    final (auth, fakes) = await _signedIn();
    await pumpApp(
      t,
      auth: auth,
      fakes: fakes,
      size: const Size(430, 2000),
      pdfPicker: FakePdfPicker(PickedPdf(name: 'scan.pdf', bytes: _scan())),
    );
    await _openResumes(t);
    await t.tap(find.text('Upload PDF'));
    await t.pumpAndSettle();
    await t.tap(find.text('Review suggestions'));
    await _wait(t);
    expect(find.textContaining('no selectable text'), findsOneWidget);
    expect(find.text('Review suggestions'), findsNothing);
    expect(fakes.profiles.profileRows.single.headline, isNull);
  });

  testWidgets(
    'without a profile, a PDF can start one (and nothing is uploaded)',
    (t) async {
      final (auth, fakes) = await _signedIn(withProfile: false);
      await pumpApp(
        t,
        auth: auth,
        fakes: fakes,
        size: const Size(430, 4000),
        pdfPicker: FakePdfPicker(
          PickedPdf(name: 'cv.pdf', bytes: _fixture('cv_en.pdf')),
        ),
      );
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await t.tap(find.text('Professional profile'));
      await t.pumpAndSettle();
      await t.tap(find.text('Start from a PDF résumé'));
      await _wait(t);
      await t.tap(find.textContaining('Apply'));
      await _wait(t, 100);
      final p = fakes.profiles.profileRows.single;
      expect(p.name, 'John A. Smith');
      expect(p.headline, 'Senior Flutter Developer');
      expect(fakes.profiles.expRows, hasLength(2));
      expect(
        fakes.resumes.rows,
        isEmpty,
        reason: 'reading a file for suggestions does not store it',
      );
    },
  );

  testWidgets('leaving the review asks before discarding', (t) async {
    final (auth, fakes) = await _signedIn();
    await pumpApp(
      t,
      auth: auth,
      fakes: fakes,
      size: const Size(430, 4000),
      pdfPicker: FakePdfPicker(
        PickedPdf(name: 'cv.pdf', bytes: _fixture('cv_es.pdf')),
      ),
    );
    await _openResumes(t);
    await _upload(t);
    await t.binding.handlePopRoute(); // system back
    await t.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await t.tap(find.text('Keep editing'));
    await t.pumpAndSettle();
    expect(find.text('Review suggestions'), findsWidgets);
  });
}
