// Account data (OrbiJob 7.0): the export ZIP, the export Cubit and the delete-account flow on the privacy screen.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/di/injector.dart';
import 'package:orbijob/core/orbi/orbi.dart';
import 'package:orbijob/features/auth/domain/auth_failure.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/privacy/data/supabase_account_data_repository.dart';
import 'package:orbijob/features/privacy/domain/account_data_repository.dart';
import 'package:orbijob/features/privacy/presentation/data_export_cubit.dart';
import 'package:orbijob/l10n/app_localizations.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');
final _pdf = Uint8List.fromList(utf8.encode('%PDF-1.4 test'));

Map<String, dynamic> _doc() => {
  'format': 'orbijob-data-export',
  'account': {'id': 'user-a', 'email': 'a@example.com'},
  'data': {
    'professional_profiles': [
      {'id': 'p1', 'name': 'Ana'},
    ],
  },
  'resume_files': [
    {
      'id': 'r1',
      'file': 'cv ana.pdf',
      'download_url': 'https://signed.example/a?t=1',
      'download_url_valid_seconds': 3600,
    },
    {
      'id': 'r2',
      'file': 'other.pdf',
      'download_url': 'https://signed.example/b?t=1',
      'download_url_valid_seconds': 3600,
    },
    {
      'id': 'r3',
      'file': 'none.pdf',
      'download_url': null,
      'download_url_valid_seconds': null,
    },
  ],
};

class _FakeData implements AccountDataRepository {
  Object? error;
  int calls = 0;
  @override
  Future<DataExport> export() async {
    calls++;
    if (error != null) throw error!;
    return DataExport(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'orbijob-data-20261014.zip',
      resumeFiles: 1,
      resumeFilesMissing: 2,
    );
  }
}

AppLocalizations _l(WidgetTester t) =>
    AppLocalizations.of(t.element(find.byType(Scaffold).first));

Future<void> _goPrivacy(WidgetTester t, AppLocalizations l) async {
  await t.scrollUntilVisible(
    find.text(l.privacyTitle),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.tap(find.text(l.privacyTitle));
  await t.pumpAndSettle();
}

Future<void> _openPrivacy(
  WidgetTester t, {
  _FakeData? data,
  List<String>? shared,
}) async {
  final auth = FakeAuth()..currentUser = _user;
  await pumpApp(
    t,
    size: const Size(430, 2400),
    fakes: Fakes(auth: auth),
    auth: auth,
  );
  if (data != null) sl.registerLazySingleton<AccountDataRepository>(() => data);
  if (shared != null) {
    sl.registerLazySingleton<DataFileShare>(
      () =>
          (e) async => shared.add(e.fileName),
    );
  }
  final l = _l(t);
  await t.tap(find.byTooltip(l.profile));
  await t.pumpAndSettle();
  await _goPrivacy(t, l);
}

void main() {
  group('export ZIP', () {
    test('holds the JSON and the downloadable PDFs, drops the signed links and reports what is missing', () async {
      final fetched = <String>[];
      final e = await packExport(
        _doc(),
        now: DateTime.utc(2026, 10, 14, 9),
        fetch: (url) async {
          fetched.add(url);
          return url.contains('/a') ? _pdf : null;
        },
      );
      expect(e.fileName, 'orbijob-data-20261014.zip');
      expect(e.resumeFiles, 1);
      expect(e.resumeFilesMissing, 2);
      expect(fetched, [
        'https://signed.example/a?t=1',
        'https://signed.example/b?t=1',
      ]);
      final zip = ZipDecoder().decodeBytes(e.bytes);
      expect(zip.files.map((f) => f.name).toSet(), {
        'orbijob-data.json',
        'resumes/1-cv_ana.pdf',
      });
      final text = utf8.decode(
        zip.findFile('orbijob-data.json')!.content as List<int>,
      );
      final json = jsonDecode(text) as Map<String, dynamic>;
      expect(text, isNot(contains('signed.example')));
      expect(json['data']['professional_profiles'][0]['name'], 'Ana');
      final files = (json['resume_files'] as List).cast<Map<String, dynamic>>();
      expect(files.map((f) => f['included_in_zip']), [true, false, false]);
      expect(files.first['zip_path'], 'resumes/1-cv_ana.pdf');
      expect(zip.findFile('resumes/1-cv_ana.pdf')!.content, _pdf);
    });

    test('works with no resumes at all', () async {
      final e = await packExport(
        {'format': 'x', 'data': <String, dynamic>{}},
        fetch: (_) async => null,
        now: DateTime.utc(2026, 1, 2),
      );
      expect(e.resumeFiles, 0);
      expect(
        ZipDecoder().decodeBytes(e.bytes).files.single.name,
        'orbijob-data.json',
      );
    });
  });

  group('export Cubit', () {
    test(
      'creates the export, hands it to the system and reports the result',
      () async {
        final shared = <String>[];
        final c = DataExportCubit(
          _FakeData(),
          share: (e) async => shared.add(e.fileName),
        );
        await c.start();
        expect(shared, ['orbijob-data-20261014.zip']);
        expect(c.state.phase, ExportPhase.done);
        expect(c.state.resumeFilesMissing, 2);
        await c.close();
      },
    );

    test('a failure is mapped, nothing is shared, and a second tap while working does nothing', () async {
      final data = _FakeData()
        ..error = const DataFailure(DataFailureKind.network);
      var shared = 0;
      final c = DataExportCubit(data, share: (_) async => shared++);
      final first = c.start();
      final second = c.start();
      await Future.wait([first, second]);
      expect(data.calls, 1);
      expect(shared, 0);
      expect(c.state.phase, ExportPhase.failed);
      expect(c.state.failure, DataFailureKind.network);
      await c.close();
    });

    test('without a backend it reports "not configured"', () async {
      final c = DataExportCubit(null);
      await c.start();
      expect(c.state.failure, DataFailureKind.notConfigured);
      await c.close();
    });
  });

  group('privacy screen', () {
    testWidgets(
      'a signed-out person is told to sign in and sees no destructive button',
      (t) async {
        await pumpApp(t, size: const Size(430, 2400));
        final l = _l(t);
        await t.tap(find.byTooltip(l.profile));
        await t.pumpAndSettle();
        await _goPrivacy(t, l);
        await t.scrollUntilVisible(
          find.text(l.pdSignInHint),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(l.pdSignInHint), findsOneWidget);
        expect(
          find.widgetWithText(OrbiSecondaryButton, l.pdDeleteTitle),
          findsNothing,
        );
      },
    );

    testWidgets('export runs from the screen', (t) async {
      final data = _FakeData();
      final shared = <String>[];
      await _openPrivacy(t, data: data, shared: shared);
      final l = _l(t);
      await t.scrollUntilVisible(
        find.widgetWithText(OrbiSecondaryButton, l.pdExportAction),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      // the system share sheet cannot open in tests: the Cubit's own share is covered above, here the repository is reached
      await t.tap(find.widgetWithText(OrbiSecondaryButton, l.pdExportAction));
      await t.pumpAndSettle();
      expect(data.calls, 1);
      expect(shared, ['orbijob-data-20261014.zip']);
      expect(find.textContaining(l.pdExportDone), findsOneWidget);
    });

    testWidgets(
      'delete: the button stays off until the box is ticked and a password typed; a wrong password deletes nothing',
      (t) async {
        final auth = FakeAuth()..currentUser = _user;
        await pumpApp(
          t,
          size: const Size(430, 2400),
          fakes: Fakes(auth: auth),
          auth: auth,
        );
        final l = _l(t);
        await t.tap(find.byTooltip(l.profile));
        await t.pumpAndSettle();
        await _goPrivacy(t, l);
        await t.scrollUntilVisible(
          find.widgetWithText(OrbiSecondaryButton, l.pdDeleteTitle),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await t.tap(find.widgetWithText(OrbiSecondaryButton, l.pdDeleteTitle));
        await t.pumpAndSettle();
        expect(find.text(l.pdDeleteAction), findsOneWidget);

        Future<void> tapDelete() async {
          await t.tap(find.text(l.pdDeleteAction));
          await t.pumpAndSettle();
        }

        await tapDelete();
        expect(
          auth.deletedWith,
          isNull,
          reason: 'nothing typed, nothing ticked',
        );
        await t.enterText(orbiField(l.pdDeletePassword), 'hunter2');
        await t.pumpAndSettle();
        await tapDelete();
        expect(
          auth.deletedWith,
          isNull,
          reason: 'password typed but the acknowledgement is missing',
        );

        await t.tap(find.byType(CheckboxListTile));
        await t.pumpAndSettle();
        auth.error = const AuthFailure(AuthFailureKind.invalidCredentials);
        await tapDelete();
        expect(find.text(l.pdDeleteWrongPassword), findsOneWidget);
        expect(
          auth.currentUser,
          isNotNull,
          reason: 'wrong password: still signed in',
        );

        auth.error = null;
        await tapDelete();
        expect(auth.deletedWith, 'hunter2');
        expect(
          auth.currentUser,
          isNotNull,
          reason: 'the confirmation comes before the sign-out',
        );
        expect(find.text(l.pdDeleted), findsOneWidget);
        await t.tap(find.text(l.pdDeletedAction));
        await t.pumpAndSettle();
        expect(auth.currentUser, isNull);
        expect(find.text(l.pdDeleted), findsNothing);
      },
    );

    testWidgets('delete: cancelling leaves everything as it was', (t) async {
      final auth = FakeAuth()..currentUser = _user;
      await pumpApp(
        t,
        size: const Size(430, 2400),
        fakes: Fakes(auth: auth),
        auth: auth,
      );
      final l = _l(t);
      await t.tap(find.byTooltip(l.profile));
      await t.pumpAndSettle();
      await _goPrivacy(t, l);
      await t.scrollUntilVisible(
        find.widgetWithText(OrbiSecondaryButton, l.pdDeleteTitle),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(find.widgetWithText(OrbiSecondaryButton, l.pdDeleteTitle));
      await t.pumpAndSettle();
      await t.tap(find.text(l.commonCancel));
      await t.pumpAndSettle();
      expect(find.text(l.pdDeleteAction), findsNothing);
      expect(auth.deletedWith, isNull);
      expect(auth.currentUser, isNotNull);
    });
  });
}
