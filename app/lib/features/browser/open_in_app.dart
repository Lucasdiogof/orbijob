import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/open_link.dart';
import '../../l10n/app_localizations.dart';
import '../applications/application_kit.dart';
import '../auth/presentation/auth_cubit.dart';
import '../search/domain/entities/job_posting.dart';
import 'in_app_browser_page.dart';
import 'url_policy.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

/// The one way the app opens a job's own site (and other outside pages): inside OrbiJob on Android and iOS, in the system
/// browser where an in-app page cannot be trusted to work (the web build: most sites forbid embedding) or for files.
///
/// Opening a page never counts as applying. When the person comes back from a job's site and has an account, a quiet prompt
/// offers to track the application; nothing is recorded unless they confirm.
Future<void> openInApp(
  BuildContext context,
  String rawUrl, {
  JobPosting? job,
  bool? forceExternal,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uri = parseBrowsableUrl(rawUrl);
  if (uri == null) {
    showSnackOn(messenger, l.applicationLinkCannotOpen);
    return;
  }
  final external =
      forceExternal ?? (kIsWeb || decideUrl(uri) == UrlVerdict.download);
  if (external) {
    final ok = await openExternalLink(uri.toString());
    if (!ok) showSnackOn(messenger, l.browserCannotOpenExternal);
    return;
  }
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => InAppBrowserPage(url: uri)));
  if (job == null || !context.mounted) return;
  if (!context.read<AuthCubit>().state.signedIn) return;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l.browserDidYouApply),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: l.kitTrack,
          onPressed: () {
            if (context.mounted) confirmAndTrackApplication(context, job);
          },
        ),
      ),
    );
}

void showSnackOn(ScaffoldMessengerState? m, String text) {
  m
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
