import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet for a link. Injected so tests do not need the platform channel.
typedef LinkShare = Future<void> Function(Uri uri);

Future<void> shareLinkWithSystem(Uri uri) =>
    SharePlus.instance.share(ShareParams(uri: uri));

/// Shares a short text (a job's title, company and link). Separate from [LinkShare], which shares a bare link from the in-app browser.
typedef TextShare = Future<void> Function(String text, {String? subject});

Future<void> shareTextWithSystem(String text, {String? subject}) =>
    SharePlus.instance.share(ShareParams(text: text, subject: subject));
