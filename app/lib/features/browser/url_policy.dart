/// What the in-app browser does with a URL. The rules are deliberately small and strict: only http(s) pages are shown inside
/// the app; mail/phone links go to the system app; anything else (script, file, data, intent, custom schemes) is refused.
enum UrlVerdict {
  /// Show it inside the app.
  allow,

  /// A file (PDF, document, archive…): hand it to the system browser, which owns downloads.
  download,

  /// `mailto:`, `tel:`, `sms:`: open the matching system app instead of navigating.
  system,

  /// Refused: never loaded, never opened elsewhere.
  block,
}

const _downloadExtensions = {
  'pdf',
  'doc',
  'docx',
  'odt',
  'rtf',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'zip',
  'rar',
  '7z',
  'apk',
  'ipa',
  'exe',
  'dmg',
  'csv',
};

const _systemSchemes = {'mailto', 'tel', 'sms'};

/// Decides what to do with [uri]. [isMainFrame] is false for iframes: those may only load web pages, silently.
UrlVerdict decideUrl(Uri uri, {bool isMainFrame = true}) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') {
    if (uri.host.isEmpty) return UrlVerdict.block;
    // credentials inside the URL (https://bank.com@evil.example) are a classic way to disguise a destination
    if (uri.userInfo.isNotEmpty) return UrlVerdict.block;
    if (isMainFrame && isDownloadPath(uri.path)) return UrlVerdict.download;
    return UrlVerdict.allow;
  }
  if (scheme == 'about' && uri.toString().toLowerCase() == 'about:blank') {
    return UrlVerdict.allow;
  }
  if (isMainFrame && _systemSchemes.contains(scheme)) return UrlVerdict.system;
  return UrlVerdict.block;
}

bool isDownloadPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return false;
  return _downloadExtensions.contains(path.substring(dot + 1).toLowerCase());
}

/// A URL string the app may open in the browser at all (links from listings): http(s) with a host and no embedded credentials.
Uri? parseBrowsableUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  return uri;
}
