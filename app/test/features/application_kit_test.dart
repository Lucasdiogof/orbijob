import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');

/// Records what the app puts on the clipboard.
List<String> _clipboard(WidgetTester t) {
  final copied = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

Future<void> _openKit(WidgetTester t) async {
  await t.tap(find.text('Explore'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField).last, 'Pedreiro');
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
  await t.tap(find.text('Construtora Exemplo'));
  await t.pumpAndSettle();
  await t.tap(find.text('Prepare my application'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'the kit lists real profile data, copies piece by piece or all at once, and says it never fills other sites',
    (t) async {
      final auth = FakeAuth()..currentUser = _user;
      final fakes = Fakes(auth: auth);
      final p = await fakes.profiles.save(
        const ProfessionalProfile(
          name: 'Maria Souza',
          countryOfResidence: 'BR',
          skills: ['Biofeedback', 'Pilates'],
          personal: {
            'headline': 'Physiotherapist',
            'email': 'maria@example.com',
            'phone': '+55 11 91234-5678',
            'city': 'São Paulo',
          },
        ),
      );
      await fakes.profiles.addExperience(
        Experience(
          profileId: p.id!,
          company: 'Clínica Vida Plena',
          title: 'Pelvic physiotherapist',
          startDate: DateTime(2019, 3),
        ),
      );
      final copied = _clipboard(t);
      await pumpApp(
        t,
        auth: auth,
        fakes: fakes,
        size: const Size(430, 2400),
        repo: PreviewSearchRepository(),
      );
      await _openKit(t);

      expect(find.text('Application kit'), findsOneWidget);
      expect(
        find.textContaining('never fills in or sends forms'),
        findsOneWidget,
      );
      expect(find.text('maria@example.com'), findsOneWidget);
      expect(find.text('São Paulo, BR'), findsOneWidget);
      expect(find.textContaining('Clínica Vida Plena'), findsOneWidget);

      await t.tap(find.byTooltip('Copy Contact e-mail'));
      await t.pumpAndSettle();
      expect(copied.last, 'maria@example.com');
      expect(find.text('Contact e-mail copied'), findsOneWidget);

      await t.tap(find.text('Copy everything'));
      await t.pumpAndSettle();
      expect(copied.last, contains('Professional name: Maria Souza'));
      expect(copied.last, contains('Phone: +55 11 91234-5678'));
      expect(copied.last, contains('Skills: Biofeedback, Pilates'));
      expect(copied.last, isNot(contains('null')));
    },
  );

  testWidgets(
    'signed out: no profile data, a sign-in hint, and the listing is still one tap away',
    (t) async {
      final auth = FakeAuth();
      await pumpApp(
        t,
        auth: auth,
        fakes: Fakes(auth: auth),
        size: const Size(430, 2400),
        repo: PreviewSearchRepository(),
      );
      await _openKit(t);
      expect(
        find.text('Sign in to use the data from your profile.'),
        findsOneWidget,
      );
      expect(find.text('Copy everything'), findsNothing);
      expect(find.text('Open original listing'), findsWidgets);
      expect(find.text('I applied: track it'), findsNothing);
    },
  );

  testWidgets('tracking asks first and records an application dated today', (
    t,
  ) async {
    final auth = FakeAuth()..currentUser = _user;
    final fakes = Fakes(auth: auth);
    await pumpApp(
      t,
      auth: auth,
      fakes: fakes,
      size: const Size(430, 2400),
      repo: PreviewSearchRepository(),
    );
    await _openKit(t);
    expect(
      find.text(
        'Your profile has no data to copy yet. Fill it in, or start from a PDF résumé.',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('I applied: track it'));
    await t.pumpAndSettle();
    expect(find.text('Track this application?'), findsOneWidget);
    expect(
      fakes.applications.rows,
      isEmpty,
      reason: 'nothing is recorded before the user confirms',
    );
    await t.tap(find.text('I applied: track it').last);
    await t.pumpAndSettle();
    expect(fakes.applications.rows, hasLength(1));
    expect(fakes.applications.rows.single.job.title, 'Pedreiro');
    expect(find.text('Added to your applications'), findsOneWidget);
  });
}
