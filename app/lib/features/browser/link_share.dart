import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet for a link. Injected so tests do not need the platform channel.
typedef LinkShare = Future<void> Function(Uri uri);

Future<void> shareLinkWithSystem(Uri uri) =>
    SharePlus.instance.share(ShareParams(uri: uri));
