import 'package:orbijob/features/translation/translation_engine.dart';

/// A stand-in engine: "translates" by wrapping the text, so tests can see exactly what reached it. It never invents words.
class FakeEngine implements TranslationEngine {
  FakeEngine({
    this.sources = const {'de', 'sv', 'zh', 'en', 'fr'},
    this.targets = const {'pt', 'en', 'es'},
    this.ready = true,
    this.latency = Duration.zero,
  });

  Set<String> sources;
  Set<String> targets;
  bool ready;
  Duration latency;
  Object? failWith;

  /// Marker mode: what to do with the ⟦n⟧ markers ('keep' | 'drop' | 'duplicate' | 'lower').
  String markers = 'keep';
  final seen = <String>[];
  var concurrent = 0;
  var maxConcurrent = 0;
  var prepared = 0;

  @override
  String get name => 'fake';
  @override
  int get approxDownloadMb => 30;
  @override
  bool supportsSource(String c) => sources.contains(c.split('-').first);
  @override
  bool supportsTarget(String c) => targets.contains(c);
  @override
  Future<EngineReadiness> readiness(String from, String to) async =>
      ready ? EngineReadiness.ready : EngineReadiness.needsDownload;
  @override
  Future<bool> prepare(String from, String to) async {
    prepared++;
    ready = true;
    return true;
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    seen.add(text);
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    try {
      if (latency > Duration.zero) await Future<void>.delayed(latency);
      if (failWith != null) throw failWith!;
      var t = text;
      if (markers == 'drop') t = t.replaceAll(RegExp(r'⟦\d+⟧'), '');
      if (markers == 'duplicate') {
        t = t.replaceAllMapped(
          RegExp(r'⟦\d+⟧'),
          (m) => '${m.group(0)} ${m.group(0)}',
        );
      }
      if (markers == 'lower') t = t.replaceAll('⟦', '[').replaceAll('⟧', ']');
      if (markers == 'mangle') {
        // an engine that drops markers and garbles acronyms (CREFITO -> creço)
        t = t
            .replaceAll(RegExp(r'⟦\d+⟧'), '')
            .replaceAllMapped(
              RegExp(r'[A-Z]{3,}'),
              (m) => '${m.group(0)!.substring(0, 3).toLowerCase()}ço',
            );
      }
      if (markers == 'titlecase') {
        // an engine that drops markers and title-cases ALL-CAPS words
        t = t
            .replaceAll(RegExp(r'⟦\d+⟧'), '')
            .replaceAllMapped(
              RegExp(r'[A-Z]{3,}'),
              (m) => m.group(0)![0] + m.group(0)!.substring(1).toLowerCase(),
            );
      }
      return '[$to] $t';
    } finally {
      concurrent--;
    }
  }

  @override
  Future<void> dispose() async {}
}
