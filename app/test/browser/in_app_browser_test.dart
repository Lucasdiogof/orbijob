import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/orbi/orbi.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/browser/browser_engine.dart';
import 'package:orbijob/features/browser/url_policy.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/browser_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');
const _listing =
    'https://example.invalid/jobs/mason'; // see PreviewSearchRepository

/// The loader animates for as long as a page is loading, so a test cannot wait for "nothing to animate".
Future<void> _settle(WidgetTester t) async {
  await t.pump(); // a new route starts its transition on the first frame
  await t.pump(const Duration(milliseconds: 500));
  final animating =
      find.byType(OrbiLoadingIndicator).evaluate().isNotEmpty ||
      find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
  if (animating) {
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 120));
    }
  } else {
    await t.pumpAndSettle();
  }
}

/// Opens the preview job "Pedreiro" and taps its "Open original listing".
Future<void> _openListing(WidgetTester t) async {
  await t.tap(find.text('Explore'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField).last, 'Pedreiro');
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
  await t.tap(find.text('Construtora Exemplo'));
  await t.pumpAndSettle();
  await t.tap(find.text('Open original listing'));
  await _settle(t);
}

Future<
  ({
    FakeBrowserEngine engine,
    List<Uri> shared,
    List<String> launched,
    Fakes fakes,
  })
>
_setup(WidgetTester t, {bool signedIn = false, bool launchOk = true}) async {
  final auth = FakeAuth();
  if (signedIn) auth.currentUser = _user;
  final fakes = Fakes(auth: auth);
  await pumpApp(
    t,
    size: const Size(430, 1600),
    auth: auth,
    fakes: fakes,
    repo: PreviewSearchRepository(),
  );
  final f = installFakeBrowser();
  final launched = mockLauncher(t, opens: launchOk);
  return (engine: f.engine, shared: f.shared, launched: launched, fakes: fakes);
}

Finder get _domain => find.byKey(const ValueKey('browser-domain'));

void main() {
  testWidgets(
    'the job site opens inside the app, with its address and HTTPS shown',
    (t) async {
      final s = await _setup(t);
      await _openListing(t);
      expect(
        s.engine.initial,
        Uri.parse(_listing),
        reason: 'the original URL, untouched',
      );
      expect(s.launched, isEmpty, reason: 'nothing went to the system browser');
      expect(t.widget<Text>(_domain).data, 'example.invalid');
      expect(find.text('HTTPS connection'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      // the hint is honest about what HTTPS does and does not prove
      expect(
        find.byTooltip(
          'HTTPS encrypts the connection. OrbiJob does not check who runs the site or what it asks of you.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('plain HTTP is labelled as not secure', (t) async {
    final s = await _setup(t);
    await _openListing(t);
    s.engine.events!.onPageStarted(
      Uri.parse('http://legacy.example.org/apply'),
    );
    await t.pump();
    expect(t.widget<Text>(_domain).data, 'legacy.example.org');
    expect(find.text('Not secure (HTTP)'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets(
    'loading: the orbital loader until the first page, a progress bar while loading',
    (t) async {
      final s = await _setup(t);
      await _openListing(t);
      expect(find.byType(OrbiLoadingIndicator), findsOneWidget);
      s.engine.events!.onProgress(40);
      await t.pump();
      final bar = t.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.4, 1e-9));
      s.engine.events!.onProgress(100);
      s.engine.events!.onPageFinished(Uri.parse(_listing));
      await t.pump();
      expect(find.byType(OrbiLoadingIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'redirects and multi-page flows: the visible domain follows the page',
    (t) async {
      final s = await _setup(t);
      await _openListing(t);
      s.engine.events!.onPageFinished(Uri.parse(_listing));
      s.engine.events!.onUrlChanged(
        Uri.parse('https://careers.greenhouse.example/acme/apply'),
      );
      await t.pump();
      expect(t.widget<Text>(_domain).data, 'careers.greenhouse.example');
      s.engine.events!.onUrlChanged(
        Uri.parse('https://forms.workable.example/x/step-2'),
      );
      await t.pump();
      expect(t.widget<Text>(_domain).data, 'forms.workable.example');
    },
  );

  testWidgets(
    'history buttons follow the web view, and the system back walks the history first',
    (t) async {
      final s = await _setup(t);
      await _openListing(t);
      IconButton button(String tip) => t.widget<IconButton>(
        find.widgetWithIcon(
          IconButton,
          tip == 'Back'
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
        ),
      );
      s.engine.events!.onPageFinished(Uri.parse(_listing));
      await t.pump();
      expect(button('Back').onPressed, isNull);
      expect(button('Forward').onPressed, isNull);

      // page 2 reached: there is history
      s.engine.controller.back = true;
      s.engine.events!.onUrlChanged(
        Uri.parse('https://example.invalid/jobs/mason/apply'),
      );
      await _settle(t);
      expect(button('Back').onPressed, isNotNull);

      // Android back button: goes back in the page, the browser stays open
      await t.binding.handlePopRoute();
      await _settle(t);
      expect(s.engine.controller.backs, 1);
      expect(find.byKey(const ValueKey('fake-web-view')), findsOneWidget);

      // at the start of the history the same press closes the browser
      s.engine.controller.back = false;
      s.engine.events!.onUrlChanged(Uri.parse(_listing));
      await _settle(t);
      await t.binding.handlePopRoute();
      await _settle(t);
      expect(find.byKey(const ValueKey('fake-web-view')), findsNothing);
      expect(
        s.engine.controller.backs,
        1,
        reason: 'no extra "go back" once there is nowhere to go',
      );
    },
  );

  testWidgets('forward and reload go to the web view', (t) async {
    final s = await _setup(t);
    await _openListing(t);
    s.engine.events!.onPageFinished(Uri.parse(_listing));
    s.engine.controller.forward = true;
    s.engine.events!.onUrlChanged(Uri.parse(_listing));
    await _settle(t);
    await t.tap(find.byTooltip('Forward'));
    await t.tap(find.byTooltip('Reload'));
    await t.pump();
    expect(s.engine.controller.forwards, 1);
    expect(s.engine.controller.reloads, 1);
  });

  testWidgets(
    'a failed load explains itself, retries, and offers the system browser',
    (t) async {
      final s = await _setup(t);
      await _openListing(t);
      s.engine.events!.onFailure(
        const BrowserFailure(description: 'net::ERR_NAME_NOT_RESOLVED'),
      );
      await t.pump();
      expect(find.text('The page could not be loaded'), findsOneWidget);
      expect(
        find.textContaining('net::ERR'),
        findsNothing,
        reason: 'raw error text is never shown',
      );

      // the page never loaded, so "try again" loads the address again
      await t.tap(find.text('Try again'));
      await t.pump();
      expect(s.engine.controller.loaded, [Uri.parse(_listing)]);
      expect(find.text('The page could not be loaded'), findsNothing);

      s.engine.events!.onFailure(const BrowserFailure(description: 'x'));
      await t.pump();
      await t.tap(find.text('Open in browser').first);
      await t.pump();
      expect(s.launched, [_listing]);
    },
  );

  testWidgets('after a page has loaded, "try again" reloads it', (t) async {
    final s = await _setup(t);
    await _openListing(t);
    s.engine.events!.onPageFinished(Uri.parse(_listing));
    s.engine.events!.onFailure(const BrowserFailure(description: 'x'));
    await t.pump();
    await t.tap(find.text('Try again'));
    await t.pump();
    expect(s.engine.controller.reloads, 1);
  });

  testWidgets('a certificate problem says so and is never clicked through', (
    t,
  ) async {
    final s = await _setup(t);
    await _openListing(t);
    s.engine.events!.onFailure(
      const BrowserFailure(description: 'tls', isTls: true),
    );
    await t.pump();
    expect(find.textContaining('security certificate'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
    'blocked schemes, downloads and system links are handled safely',
    (t) async {
      final s = await _setup(t);
      await _openListing(t);
      s.engine.events!.onVerdict(
        Uri.parse('javascript:alert(1)'),
        UrlVerdict.block,
      );
      await t.pump();
      expect(find.text('A link was blocked for your safety.'), findsWidgets);
      expect(
        s.launched,
        isEmpty,
        reason: 'a blocked link is not opened anywhere else either',
      );

      s.engine.events!.onVerdict(
        Uri.parse('https://example.com/vaga.pdf'),
        UrlVerdict.download,
      );
      await t.pump();
      await t.pump();
      expect(s.launched, ['https://example.com/vaga.pdf']);
      expect(find.textContaining('downloaded by your browser'), findsOneWidget);

      s.engine.events!.onVerdict(
        Uri.parse('mailto:rh@example.com'),
        UrlVerdict.system,
      );
      await t.pump();
      await t.pump();
      expect(s.launched.last, 'mailto:rh@example.com');
    },
  );

  testWidgets(
    'menu: copy link, share link and open in the browser use the current page',
    (t) async {
      final s = await _setup(t);
      String? clip;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clip = (call.arguments as Map)['text'] as String;
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
      await _openListing(t);
      s.engine.events!.onUrlChanged(
        Uri.parse('https://careers.example.net/step/2?token=abc'),
      );
      await t.pump();

      await t.tap(find.byTooltip('More options'));
      await _settle(t);
      await t.tap(find.text('Copy link'));
      await _settle(t);
      expect(clip, 'https://careers.example.net/step/2?token=abc');
      expect(find.text('Link copied'), findsOneWidget);

      await t.tap(find.byTooltip('More options'));
      await _settle(t);
      await t.tap(find.text('Share link'));
      await _settle(t);
      expect(s.shared, [
        Uri.parse('https://careers.example.net/step/2?token=abc'),
      ]);

      await t.tap(find.byTooltip('More options'));
      await _settle(t);
      await t.tap(find.text('Open in browser').last);
      await _settle(t);
      expect(s.launched, ['https://careers.example.net/step/2?token=abc']);
    },
  );

  testWidgets(
    'opening a site is not applying; coming back offers to track, and only a confirmation records it',
    (t) async {
      final s = await _setup(t, signedIn: true);
      await _openListing(t);
      await t.tap(find.byKey(const ValueKey('browser-close')));
      await _settle(t);
      expect(
        s.fakes.applications.rows,
        isEmpty,
        reason: 'visiting the site records nothing',
      );
      expect(find.text('Did you apply?'), findsOneWidget);

      await t.tap(find.text('I applied: track it'));
      await _settle(t);
      expect(
        s.fakes.applications.rows,
        isEmpty,
        reason: 'still nothing before the confirmation',
      );
      expect(find.text('Track this application?'), findsOneWidget);
      await t.tap(find.text('I applied: track it').last);
      await _settle(t);
      final r = s.fakes.applications.rows.single;
      expect(r.job.title, 'Pedreiro');
      expect(
        r.job.originalUrl,
        _listing,
        reason: 'the original URL is preserved',
      );
      expect(
        r.channel,
        'Example source',
        reason: 'the source attribution is preserved',
      );
    },
  );

  testWidgets('signed out: closing the browser asks nothing', (t) async {
    await _setup(t);
    await _openListing(t);
    await t.tap(find.byKey(const ValueKey('browser-close')));
    await _settle(t);
    expect(find.text('Did you apply?'), findsNothing);
  });

  testWidgets('the application kit uses the same in-app behaviour', (t) async {
    final s = await _setup(t, signedIn: true);
    await t.tap(find.text('Explore'));
    await _settle(t);
    await t.enterText(find.byType(TextField).last, 'Pedreiro');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await _settle(t);
    await t.tap(find.text('Construtora Exemplo'));
    await _settle(t);
    await t.tap(find.text('Prepare my application'));
    await _settle(t);
    await t.tap(find.text('Open original listing').last);
    await _settle(t);
    expect(s.engine.initial, Uri.parse(_listing));
    expect(s.launched, isEmpty);
  });

  testWidgets(
    'a discreet notice says the page may be in another language, and can be dismissed',
    (t) async {
      await _setup(t);
      await _openListing(t);
      expect(find.textContaining('may be in another language'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('browser-notice-close')));
      await _settle(t);
      expect(find.textContaining('may be in another language'), findsNothing);
    },
  );
}
