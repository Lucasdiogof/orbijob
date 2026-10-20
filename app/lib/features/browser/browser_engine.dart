import 'package:flutter/widgets.dart';

import 'url_policy.dart';

/// What the page (and the engine under it) can do, kept apart from any plugin so the browser screen can be tested
/// without a platform WebView.
abstract class BrowserController {
  Future<void> load(Uri uri);
  Future<void> reload();
  Future<void> goBack();
  Future<void> goForward();
  Future<bool> canGoBack();
  Future<bool> canGoForward();
}

/// Why the main page failed to load. The text is never shown to the user as-is; the screen explains in its own words.
class BrowserFailure {
  const BrowserFailure({required this.description, this.isTls = false});
  final String description;
  final bool isTls;
}

/// Callbacks from the engine to the screen. Only navigation facts are reported: no page content, form data, cookies or
/// headers ever leave the web view.
class BrowserEvents {
  const BrowserEvents({
    required this.onProgress,
    required this.onPageStarted,
    required this.onPageFinished,
    required this.onUrlChanged,
    required this.onFailure,
    required this.onVerdict,
  });

  final void Function(int percent) onProgress;
  final void Function(Uri uri) onPageStarted;
  final void Function(Uri uri) onPageFinished;
  final void Function(Uri uri) onUrlChanged;
  final void Function(BrowserFailure failure) onFailure;

  /// Reported for every navigation request that is not simply allowed (blocked schemes, downloads, system links).
  final void Function(Uri uri, UrlVerdict verdict) onVerdict;
}

/// Runs every clean-up [steps] one by one: a step that throws or hangs ([timeout]) never stops the others, and the whole never blocks
/// a sign-out for long. Returns how many steps failed.
Future<int> runCleanupSteps(
  Iterable<Future<void> Function()> steps, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  var failed = 0;
  for (final step in steps) {
    try {
      await step().timeout(timeout);
    } catch (_) {
      failed++;
    }
  }
  return failed;
}

/// Creates the platform web view. [onCreated] hands back the controller once the view exists.
abstract class BrowserEngine {
  Widget view({
    required Uri initial,
    required BrowserEvents events,
    required ValueChanged<BrowserController> onCreated,
  });

  /// Removes what the web view kept for the sites visited (cookies), so the next person on this device does not inherit a portal session.
  Future<void> clearData();
}
