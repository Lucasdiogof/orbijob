import 'package:url_launcher/url_launcher.dart';

/// Opens an http(s) link in the system browser. Returns false when it cannot (never throws to the UI).
Future<bool> openExternalLink(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Hands a `mailto:`, `tel:` or `sms:` link to the matching system app. Any other scheme is refused.
Future<bool> openSystemLink(Uri uri) async {
  if (!const {'mailto', 'tel', 'sms'}.contains(uri.scheme.toLowerCase())) {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
