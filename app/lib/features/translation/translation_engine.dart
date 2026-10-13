/// What a translation engine can do for a language pair on this device.
enum EngineReadiness {
  /// This engine cannot translate that pair (or does not exist on this platform).
  unsupported,

  /// Supported, but language data must be downloaded first (needs the person's consent).
  needsDownload,

  /// Ready to translate right now, offline.
  ready,
}

/// A translator that runs on the device. Nothing the user reads is ever sent to a server by an engine.
abstract class TranslationEngine {
  /// A short name for diagnostics and the "translated automatically" note.
  String get name;

  /// BCP-47 primary subtags this engine can translate from / to.
  bool supportsSource(String code);
  bool supportsTarget(String code);

  Future<EngineReadiness> readiness(String from, String to);

  /// Approximate size of the data a download brings, in megabytes (shown before asking for consent).
  int get approxDownloadMb;

  /// Downloads what [readiness] reported as `needsDownload`. Returns false when it could not.
  Future<bool> prepare(String from, String to);

  /// Translates one piece of text (a line or a sentence). Throws on failure; never returns the input pretending it worked.
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  });

  /// Releases any native resources (translators hold language data in memory).
  Future<void> dispose();
}

/// Used where no engine exists (for example the web on browsers without a built-in translator): everything is unsupported.
class NoTranslationEngine implements TranslationEngine {
  const NoTranslationEngine();

  @override
  String get name => 'none';
  @override
  bool supportsSource(String code) => false;
  @override
  bool supportsTarget(String code) => false;
  @override
  Future<EngineReadiness> readiness(String from, String to) async =>
      EngineReadiness.unsupported;
  @override
  int get approxDownloadMb => 0;
  @override
  Future<bool> prepare(String from, String to) async => false;
  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) => throw UnsupportedError('no translation engine');
  @override
  Future<void> dispose() async {}
}
