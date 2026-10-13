import 'occupation_labels.g.dart';
import 'search_alternatives.dart';
import 'search_synonyms.dart';

/// What to offer when a search finds nothing: a broader search of the same profession ("fisioterapia pélvica" -> "fisioterapia") or a
/// profession with a similar spelling ("enfermeria" -> "enfermeiro"). Deterministic and offline; nothing is guessed beyond the ESCO labels
/// and the hand-made groups, and a suggestion is only a search the person may choose.
List<String> searchSuggestions(String term, {int max = 3}) {
  final t = term.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length < 4) return const [];
  final out = <String>[];
  void add(String s) {
    if (s != t && !out.contains(s) && out.length < max) out.add(s);
  }

  final words = t.split(' ');
  if (words.length > 1) {
    // the same profession without the words that narrowed it: each remaining word that is itself a profession
    for (final w in words) {
      if (w.length >= 4 && _isProfession(w)) add(w);
    }
  }
  if (out.isEmpty && !_isProfession(t)) {
    for (final s in _similar(t)) {
      add(s);
    }
  }
  return out;
}

bool _isProfession(String w) =>
    escoOccupationsOf(w).isNotEmpty ||
    synonymGroups.any((g) => g.any((f) => w.startsWith(f))) ||
    titleAlternatives(w).isNotEmpty;

// --- spelling -------------------------------------------------------------------------------------------------------------------------

Map<String, String>? _names;

/// Folded single- and two-word names -> the label as ESCO writes it (first one wins).
Map<String, String> get _professionNames => _names ??= () {
  final m = <String, String>{};
  for (final o in escoOccupations) {
    for (final l in o.labels) {
      if (l.split(' ').length > 2) continue;
      m.putIfAbsent(_foldText(l), () => l);
    }
  }
  return m;
}();

String _foldText(String s) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}

/// Labels within one edit (two for long words) of [t], the closest first; the first letter must agree, which is where typos rarely happen.
List<String> _similar(String t) {
  final f = _foldText(t);
  if (f.length < 5) return const [];
  final budget = f.length >= 9 ? 2 : 1;
  final found = <(int, String)>[];
  for (final e in _professionNames.entries) {
    final k = e.key;
    if ((k.length - f.length).abs() > budget || k[0] != f[0]) continue;
    final d = _distance(f, k, budget);
    if (d > 0 && d <= budget) found.add((d, e.value));
  }
  found.sort((a, b) {
    final c = a.$1.compareTo(b.$1);
    return c != 0 ? c : a.$2.length.compareTo(b.$2.length);
  });
  return [for (final x in found.take(6)) x.$2];
}

/// Levenshtein distance, giving up (returning budget + 1) once it cannot stay within [budget].
int _distance(String a, String b, int budget) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final v = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      cur[j] = v;
      if (v < rowMin) rowMin = v;
    }
    if (rowMin > budget) return budget + 1;
    prev = cur;
  }
  return prev[b.length];
}
