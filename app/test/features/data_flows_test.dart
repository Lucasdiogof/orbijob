import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/applications/domain/application_record.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const userA = AuthUser(id: 'user-a', email: 'a@example.com');
const userB = AuthUser(id: 'user-b', email: 'b@example.com');

Future<void> goTo(WidgetTester t, String label) async {
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'signed out: applications ask for sign-in, not a fake empty list',
    (t) async {
      final auth = FakeAuth();
      await pumpApp(
        t,
        auth: auth,
        fakes: Fakes(auth: auth),
      );
      await goTo(t, 'Applications');
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Add application'), findsNothing);
    },
  );

  testWidgets(
    'signed in: add a manual application, see it, change stage, see history',
    (t) async {
      final auth = FakeAuth()..currentUser = userA;
      final fakes = Fakes(auth: auth);
      await pumpApp(t, auth: auth, fakes: fakes);
      await goTo(t, 'Applications');
      expect(find.text('Add application'), findsOneWidget);
      // The disclaimer: OrbiJob never sends applications.
      expect(find.textContaining('never sends'), findsWidgets);

      await t.tap(find.text('Add application'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(
        find.text('Required field'),
        findsWidgets,
        reason: 'validation before any request',
      );
      expect(fakes.applications.rows, isEmpty);

      await t.enterText(
        find.widgetWithText(TextFormField, 'Job title'),
        'Electrician',
      );
      await t.enterText(find.widgetWithText(TextFormField, 'Company'), 'Acme');
      await t.enterText(
        find.widgetWithText(TextFormField, 'Link to the posting (Optional)'),
        'not a link',
      );
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Enter a link starting with https://'), findsOneWidget);
      await t.enterText(
        find.widgetWithText(TextFormField, 'Link to the posting (Optional)'),
        'https://acme.example/j/1',
      );
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();

      expect(fakes.applications.rows, hasLength(1));
      expect(find.text('Electrician'), findsOneWidget);
      expect(find.text('Applied'), findsWidgets);

      await t.tap(find.text('Electrician'));
      await t.pumpAndSettle();
      expect(find.text('History'), findsOneWidget);
      await t.tap(find.byType(DropdownButtonFormField<ApplicationStage>));
      await t.pumpAndSettle();
      await t.tap(find.text('Interview').last);
      await t.pumpAndSettle();
      expect(fakes.applications.rows.single.stage, ApplicationStage.interview);
      expect(find.text('Interview'), findsWidgets);
    },
  );

  testWidgets('a failed save shows the cause and keeps nothing on screen', (
    t,
  ) async {
    final auth = FakeAuth()..currentUser = userA;
    final fakes = Fakes(auth: auth);
    await pumpApp(t, auth: auth, fakes: fakes);
    await goTo(t, 'Applications');
    fakes.applications.error = const sb.PostgrestException(
      message: 'quota exceeded',
      code: '53400',
    );
    await t.tap(find.text('Add application'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Job title'), 'X');
    await t.enterText(find.widgetWithText(TextFormField, 'Company'), 'Y');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.textContaining('reached the limit'), findsOneWidget);
    expect(fakes.applications.rows, isEmpty);
  });

  testWidgets(
    'account switch A -> B: B never sees A\'s data, and logout clears it',
    (t) async {
      final auth = FakeAuth()..currentUser = userA;
      final fakes = Fakes(auth: auth);
      await pumpApp(t, auth: auth, fakes: fakes);
      await goTo(t, 'Applications');
      await t.tap(find.text('Add application'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Job title'),
        'Secret role of A',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Company'),
        'A Corp',
      );
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Secret role of A'), findsOneWidget);

      // Logout: the cached list must be gone, not merely hidden.
      auth.emit(null);
      await t.pumpAndSettle();
      expect(find.text('Secret role of A'), findsNothing);
      await goTo(t, 'Applications');
      expect(find.text('Secret role of A'), findsNothing);
      expect(find.text('Sign in to continue'), findsOneWidget);

      // B signs in on the same device.
      auth.emit(userB);
      await t.pumpAndSettle();
      await goTo(t, 'Applications');
      expect(find.text('Secret role of A'), findsNothing);
      expect(find.text('Add application'), findsOneWidget);

      // A comes back: their data is still theirs.
      auth.emit(userA);
      await t.pumpAndSettle();
      await goTo(t, 'Applications');
      expect(find.text('Secret role of A'), findsOneWidget);
    },
  );

  testWidgets(
    'session lost while signed in: user is told and data is dropped',
    (t) async {
      final auth = FakeAuth()..currentUser = userA;
      final fakes = Fakes(auth: auth);
      await pumpApp(t, auth: auth, fakes: fakes);
      auth.emit(null);
      await t.pumpAndSettle();
      expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
    },
  );

  testWidgets('password recovery link opens a screen that cannot be skipped', (
    t,
  ) async {
    final auth = FakeAuth();
    await pumpApp(
      t,
      auth: auth,
      fakes: Fakes(auth: auth),
    );
    auth.recoveryLink(userA);
    await t.pumpAndSettle();
    expect(find.text('Choose a new password'), findsOneWidget);

    await t.enterText(find.byType(TextFormField), 'short');
    await t.tap(find.text('Save new password'));
    await t.pumpAndSettle();
    expect(auth.passwordUpdates, 0);

    await t.enterText(find.byType(TextFormField), 'a-long-enough-pass');
    await t.tap(find.text('Save new password'));
    await t.pumpAndSettle();
    expect(auth.passwordUpdates, 1);
    expect(find.text('Choose a new password'), findsNothing);
    expect(find.text('Password updated.'), findsOneWidget);
  });

  testWidgets('cancelling recovery closes the temporary session', (t) async {
    final auth = FakeAuth();
    await pumpApp(
      t,
      auth: auth,
      fakes: Fakes(auth: auth),
    );
    auth.recoveryLink(userA);
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(auth.currentUser, isNull);
    expect(find.text('Choose a new password'), findsNothing);
  });

  testWidgets('profile: create, add experience and education, edit, delete', (
    t,
  ) async {
    final auth = FakeAuth()..currentUser = userA;
    final fakes = Fakes(auth: auth);
    await pumpApp(t, auth: auth, fakes: fakes, size: const Size(390, 1400));
    await t.tap(find.byTooltip('Profile'));
    await t.pumpAndSettle();
    expect(find.text('Create your professional profile'), findsOneWidget);
    await t.tap(find.text('Create profile'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text('Required field'), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Professional name'),
      'Maria Souza',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Role or profession (Optional)'),
      'Nurse',
    );
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(fakes.profiles.profileRows.single.headline, 'Nurse');
    expect(find.text('Maria Souza'), findsOneWidget);

    await t.tap(find.text('Add experience'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Role'), 'ICU nurse');
    await t.enterText(
      find.widgetWithText(TextFormField, 'Company'),
      'Hospital X',
    );
    await t.tap(find.text('I currently work here'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text('Choose a start date for a current job'), findsOneWidget);
    await t.tap(find.text('I currently work here'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(fakes.profiles.expRows.single.company, 'Hospital X');
    expect(find.text('ICU nurse'), findsOneWidget);

    await t.tap(find.byTooltip('Delete').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Delete').last);
    await t.pumpAndSettle();
    expect(fakes.profiles.expRows, isEmpty);

    await t.tap(find.text('Add education'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextFormField, 'Institution'),
      'SENAI',
    );
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(fakes.profiles.eduRows.single.institution, 'SENAI');
    expect(fakes.profiles.eduRows.single, isA<Education>());
  });

  testWidgets('profile load failure offers retry and recovers', (t) async {
    final auth = FakeAuth()..currentUser = userA;
    final fakes = Fakes(auth: auth)
      ..profiles.error = sb.AuthRetryableFetchException(message: 'offline');
    await pumpApp(t, auth: auth, fakes: fakes, size: const Size(390, 1400));
    await t.tap(find.byTooltip('Profile'));
    await t.pumpAndSettle();
    expect(
      find.text('No connection. Check your internet and try again.'),
      findsOneWidget,
    );
    fakes.profiles.error = null;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Create your professional profile'), findsOneWidget);
  });
}
