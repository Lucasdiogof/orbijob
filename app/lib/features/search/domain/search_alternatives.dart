import 'occupation_labels.g.dart';
import 'search_synonyms.dart';

/// The other names of a profession, as the catalogue query and the alert matcher use them.
///
/// Every alternative is a list of parts that must ALL be inside the job TITLE (a one-part alternative is a plain fragment). Keeping the parts
/// together is what stops "civil engineer" from becoming "any engineer" and "pelvic physiotherapy" from becoming "any physiotherapy".
///
/// Two sources, both deterministic and offline:
/// * the hand-made groups of [synonymGroups] (stems such as `fisioterap`), with the words the person adds to the profession kept as required
///   parts ("desenvolvedor flutter" -> [flutter, developer], [flutter, entwickler]);
/// * the ESCO occupations (`occupation_labels.g.dart`): when the term is a name of an occupation, the names that occupation has in the other
///   languages of the catalogue ("engenheiro civil" -> civil engineer, ingeniero civil, Bauingenieur). Nothing is inferred beyond a label match.
///
/// Nothing here says a qualification or registration is recognised abroad: it only widens the words searched in titles.
List<List<String>> titleAlternatives(String term, {int max = 40}) {
  final t = term.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length < 3) return const [];
  final own = _words(t).toSet();
  final esco = _fromEsco(t);
  // When ESCO knows the term as an occupation ("bauingenieur"), its own labels are exact; the loose stems of the hand-made groups would
  // only add every other engineer. They then apply only when the stem starts a word of the term ("physiotherapist"), not when it is
  // buried in a compound.
  final all = <List<String>>[
    ..._fromGroups(t, strict: esco.isNotEmpty),
    ...esco,
  ];

  final seen = <String>{};
  final kept = <List<String>>[];
  for (final a in all) {
    if (a.isEmpty || a.any(_unsafe.hasMatch)) continue;
    if (a.length == 1 && _falseFriends.contains(a.first)) continue;
    // the term itself, already searched (a one-part alternative); with several parts it is the same words kept together, which only differ from
    // the typed phrase when something else may sit between them ("Desenvolvedor(a) Flutter" for "desenvolvedor flutter")
    if (a.length == 1 && a.every(own.contains)) continue;
    if (a.length > 1 && a.every(own.contains) && own.length < 2) continue;
    // narrower than the term, which already covers it
    if (a.any((p) => p.contains(t))) continue;
    if (seen.add((a.toList()..sort()).join('|'))) kept.add(a);
  }
  // an alternative that contains every part of a looser one adds nothing
  final pruned = [
    for (final a in kept)
      if (!kept.any(
        (b) =>
            !identical(a, b) &&
            b.length <= a.length &&
            b.every((p) => a.any((q) => q.contains(p))) &&
            !_same(a, b),
      ))
        a,
  ];
  return pruned.take(max).toList();
}

bool _same(List<String> a, List<String> b) =>
    a.length == b.length && a.every(b.contains);

/// The flat fragments the older code paths used (recommendations): the single-part alternatives.
List<String> titleAlternativeFragments(String term) => [
  for (final a in titleAlternatives(term))
    if (a.length == 1) a.first,
];

/// True when [title] (any case) contains every part of at least one alternative.
bool titleHasAlternative(String title, List<List<String>> alternatives) {
  final t = title.toLowerCase();
  return alternatives.any((a) => a.every(t.contains));
}

/// Fragments that are safe in a PostgREST `or=(...)` filter and in a LIKE pattern.
final RegExp _cjk = RegExp(r'[\u3400-\u9fff]');

final RegExp _unsafe = RegExp(r'[(),*"\\%_:;]');

/// Words that are a profession in one language and something else in another ("chef" is a manager in Swedish and French), so they never
/// stand alone as the name of another profession. The person's own typed word is still searched.
const Set<String> _falseFriends = {
  'controller',
  'mechanic',
  'revisor',
  'lasser',
  'chef',
  'chefe',
  'boss',
  'head',
  'direktör',
};

const Set<String> _noise = {
  // part of the name "pelvic floor", never a profession's qualifier
  'floor',
  'health',
  'saúde',
  'saude',
  'salud',
  'gesundheit',
  'hälsa',
  'jobs',
  'vaga',
  'vagas',
  'job',
  'stellen',
};

const Set<String> _stop = {
  'de',
  'do',
  'da',
  'dos',
  'das',
  'del',
  'la',
  'le',
  'les',
  'el',
  'en',
  'et',
  'of',
  'the',
  'and',
  'for',
  'für',
  'und',
  'von',
  'van',
  'het',
  'een',
  'och',
  'por',
  'para',
  'con',
  'sin',
  'with',
  'au',
  'aux',
  'des',
  'du',
};

List<String> _words(String s) => [
  for (final w in s.split(RegExp(r'[\s/]+')))
    if (w.length >= 3 && !_stop.contains(w)) w,
];

// --- hand-made groups -----------------------------------------------------------------------------------------------------------------

List<List<String>> _fromGroups(String t, {required bool strict}) {
  // Accents are ignored when the term is compared with the groups ("medico" is "médico"); the alternatives themselves keep their accents, since
  // they are what the titles are searched for.
  final ft = _fold(t);
  final tokens = ft.split(RegExp(r'[\s/-]+'));
  // a multi-word fragment ("administrative assistant") must start at a word of the term
  bool has(String f0) {
    final f = _fold(f0);
    return !strict
        ? ft.contains(f)
        : f.contains(' ')
        ? ft.startsWith(f) || ft.contains(' $f')
        : tokens.any((w) => w.startsWith(f));
  }

  final hits = <List<String>, List<String>>{
    for (final g in synonymGroups) g: g.where(has).toList(),
  }..removeWhere((_, h) => h.isEmpty);
  // A group whose every hit lies inside a longer hit of another group is part of that group's name: "truck driver" is the truck-driver
  // profession, not "driver" plus a "truck" qualifier.
  hits.removeWhere(
    (g, h) => hits.entries.any(
      (o) =>
          !identical(o.key, g) &&
          h.every(
            (x) => o.value.any(
              (y) => y.length > x.length && _fold(y).contains(_fold(x)),
            ),
          ),
    ),
  );
  final matched = hits.keys.toList();
  final consumed = [for (final h in hits.values) ...h];
  if (matched.isEmpty) return const [];
  // The words the person adds to the profession ("flutter", "civil") stay required in every alternative. With two groups the second one IS
  // the qualifier ("fisioterapia pélvica"), and generic words ("health") would only exclude the same job written in another language.
  final qualifiers = matched.length > 1
      ? const <String>[]
      : [
          for (final w in _words(t.replaceAll('-', ' ')))
            // a word of the matched name itself is not a qualifier ("trabalhador de armazém" is one name)
            if (!consumed.any((c) {
                  final fc = _fold(c).replaceAll('-', ' ');
                  final fw = _fold(w);
                  // a plural or inflected form of a word of the name ("projetos" for "gerente de projeto") is part of the name, not a qualifier
                  return fw.contains(fc) ||
                      fc
                          .split(' ')
                          .any(
                            (cw) =>
                                cw == fw ||
                                (cw.length >= 5 && fw.startsWith(cw)),
                          );
                }) &&
                !_noise.contains(w))
              w,
        ];
  // one choice per matched group; the combination made only of the term's own fragments is the term itself
  var combos = <List<String>>[[]];
  for (final g in matched) {
    combos = [
      for (final c in combos)
        for (final f in g)
          if (matched.length == 1 || !_cjk.hasMatch(f)) [...c, f],
    ];
  }
  int ownCount(List<String> c) => c.where(t.contains).length;
  // with qualifiers or several words, a combination of the term's own fragments is the same words not kept adjacent (not the term itself): "(a)", a
  // seniority word or "Health" may sit between "desenvolvedor" and "flutter", or "pelvic" and "physiotherapist"
  combos = [
    for (final c in combos)
      if (ownCount(c) < c.length ||
          qualifiers.isNotEmpty ||
          _words(t).length >= 2)
        c,
  ];
  // stable: cross-language combinations first, the generated order otherwise
  final order = {for (var i = 0; i < combos.length; i++) combos[i]: i};
  combos.sort((a, b) {
    final c = ownCount(a).compareTo(ownCount(b));
    return c != 0 ? c : order[a]!.compareTo(order[b]!);
  });
  return [
    for (final c in combos) [...qualifiers, ...c],
  ];
}

// --- ESCO -----------------------------------------------------------------------------------------------------------------------------

String _fold(String s) {
  // Latin letters with marks, incl. Czech, Polish and Nordic ones (č ř š ž ě ů ł ø ...), so "kuchar" finds "kuchař"
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿčďěňřšťůžľĺŕłśźżćńąęøő';
  const to = 'aaaaaaceeeeiiiinooooouuuuyycdenrstuzllrlszzcnaeoo';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}

Map<String, List<int>>? _index;

Map<String, List<int>> get _labelIndex => _index ??= () {
  final m = <String, List<int>>{};
  for (var i = 0; i < escoOccupations.length; i++) {
    for (final l in escoOccupations[i].labels) {
      final list = m.putIfAbsent(_fold(l), () => <int>[]);
      if (list.isEmpty || list.last != i) list.add(i);
    }
  }
  return m;
}();

/// The occupations [term] is a name of: the exact label, or the same label in the other grammatical gender ("enfermeira" / "enfermeiro").
List<int> escoOccupationsOf(String term) {
  final f = _fold(term.trim());
  if (f.length < 4) return const [];
  final keys = <String>{f};
  if (f.length >= 6 && 'aeo'.contains(f[f.length - 1])) {
    final stem = f.substring(0, f.length - 1);
    keys.addAll(['${stem}a', '${stem}o', '${stem}e']);
  }
  final out = <int>{};
  for (final k in keys) {
    out.addAll(_labelIndex[k] ?? const []);
  }
  return out.toList();
}

List<List<String>> _fromEsco(String t) {
  final occ = escoOccupationsOf(t);
  if (occ.isEmpty || occ.length > 4) return const [];
  final f = _fold(t);
  final out = <List<String>>[];
  for (final i in occ) {
    for (final l in escoOccupations[i].labels) {
      if (_fold(l) == f) continue;
      final parts = _words(l);
      // a short single word ("lasser", "cook") is too likely to sit inside another word of a title; five letters are enough when one of
      // them carries a mark ("řidič"), which almost never happens by chance
      final w = parts.isEmpty ? '' : parts.first;
      final marked = w.runes.any((r) => r > 127);
      if (parts.isNotEmpty &&
          (parts.length > 1 || w.length >= 6 || (w.length >= 5 && marked))) {
        out.add(parts);
      }
    }
  }
  return out;
}
