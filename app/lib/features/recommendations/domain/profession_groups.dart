import '../../search/domain/occupation_labels.g.dart';
import 'match_text.dart';

/// Which occupation group (ISCO-08, 4 digits) a piece of text names, so the recommender can tell "the same profession", "a related one"
/// and "only the same general area" apart instead of treating every health, engineering or technology title as alike.
///
/// Two sources, both honest about what they know:
///  1. ESCO (CC BY 4.0, the table already shipped for the search): 31,000+ names in seven languages, each tied to the ISCO group of its
///     occupation. Names shared by more than six occupations were dropped when the table was built, so very generic words ("nurse",
///     "doctor", "teacher", "driver") are NOT in it;
///  2. [_curated]: a short list of exactly those generic words and of a few titles ESCO does not list ("flutter developer", "software
///     engineer"), each mapped to the ISCO group it belongs to. Every entry is a plain statement of what the word means, nothing more.
/// Nothing here says a qualification, registration or visa from one country counts in another.
class OccupationMatch {
  const OccupationMatch(this.codes, this.words, {this.curated = false});

  /// The name comes from the curated list (a generic word or a title ESCO lacks), so it is specific by decision.
  final bool curated;

  /// ISCO-08 unit groups of the longest name found in the text (several when the name belongs to more than one occupation).
  final Set<String> codes;

  /// How many words that longest name has: "engenheiro eletricista" (2) is more specific than "eletricista" (1).
  final int words;

  bool get known => codes.isNotEmpty;
  static const none = OccupationMatch({}, 0);
}

const _curated = <String, List<String>>{
  // the same "health" area but different regulated professions
  '2221': [
    'nurse',
    'registered nurse',
    'staff nurse',
    'enfermeiro',
    'enfermeira',
    'enfermero',
    'enfermera',
    'krankenpfleger',
    'krankenschwester',
    'gesundheits und krankenpfleger',
    'pflegefachkraft',
    'pflegefachfrau',
    'pflegefachmann',
    'sjukskoterska',
    'verpleegkundige',
    'infirmier',
    'infirmiere',
  ],
  '2211': [
    'physician',
    'doctor',
    'medical doctor',
    'general practitioner',
    'medico',
    'medica',
    'arzt',
    'arztin',
    'facharzt',
    'facharztin',
    'assistenzarzt',
    'oberarzt',
    'lakare',
    'dokter',
    'medecin',
  ],
  '5321': [
    'nursing assistant',
    'nurse assistant',
    'care assistant',
    'healthcare assistant',
    'health care assistant',
    'auxiliar de enfermagem',
    'auxiliar de enfermeria',
    'pflegehelfer',
    'pflegehelferin',
    'pflegeassistent',
    'pflegeassistentin',
    'underskoterska',
    'cuidador de idosos',
    'cuidadora de idosos',
    'caregiver',
    'carer',
    'care worker',
  ],
  '3221': [
    'tecnico de enfermagem',
    'tecnica de enfermagem',
    'tecnico em enfermagem',
    'nursing associate',
  ],
  // a teacher is not a teaching assistant
  '2330': [
    'teacher',
    'professor',
    'professora',
    'profesor',
    'profesora',
    'lehrer',
    'lehrerin',
    'larare',
    'docente',
    'maestro',
    'maestra',
  ],
  '5312': [
    'teaching assistant',
    'teacher assistant',
    'teacher aide',
    'classroom assistant',
    'assistente de ensino',
    'assistente de professor',
    'auxiliar de professor',
    'auxiliar de ensino',
    'lehrassistent',
    'lehrassistentin',
    'skolassistent',
    'asistente de profesor',
  ],
  // the qualifier decides the function ("engenheiro eletricista" is not "eletricista")
  '2151': [
    'engenheiro eletricista',
    'engenheira eletricista',
    'ingeniero electricista',
    'elektroingenieur',
    'elektroingenieurin',
    'electrical engineer',
  ],
  '2512': [
    'software engineer',
    'engenheiro de software',
    'engenheira de software',
    'ingeniero de software',
    'softwareentwickler',
    'softwareentwicklerin',
    'softwareingenieur',
    'software ingenjor',
    'mjukvaruutvecklare',
    'programador',
    'programadora',
    'desenvolvedor de software',
  ],
  '2514': [
    'flutter developer',
    'flutter engineer',
    'flutter entwickler',
    'desenvolvedor flutter',
    'desarrollador flutter',
    'mobile developer',
    'mobile engineer',
    'android developer',
    'ios developer',
    'desenvolvedor mobile',
    'desenvolvedor android',
    'desenvolvedor ios',
    'desarrollador movil',
    'mobile entwickler',
    'app entwickler',
    'app developer',
  ],
  '8332': [
    'truck driver',
    'lorry driver',
    'caminhoneiro',
    'motorista de caminhao',
    'camionero',
    'lkw fahrer',
    'berufskraftfahrer',
    'fernfahrer',
  ],
  '8322': ['car driver', 'taxi driver', 'motorista de aplicativo', 'taxista'],
};

/// Unit groups that are close enough to be called "related" without being the same: small clusters whose members are neighbours of each
/// other. Broad minor groups (all engineers, all "other health professionals", systems analysts with data scientists) are deliberately NOT listed.
const _relatedClusters = [
  {'2512', '2513', '2514', '2519'}, // software, web and application developers
];

Map<String, Set<String>>? _index;
final Set<String> _curatedKeys = {
  for (final v in _curated.values)
    for (final l in v) normalizeForMatch(l),
};

/// A single word that appears in the names of this many different occupation groups or more ("assistant", "manager", "charge", "agent") is a
/// role word, not a profession: alone it says nothing and is not read as a name.
const _genericSpread = 12;
Map<String, Set<String>> _labels() {
  final cached = _index;
  if (cached != null) return cached;
  final map = <String, Set<String>>{};
  final spread = <String, Set<String>>{};
  for (final o in escoOccupations) {
    for (final l in o.labels) {
      final n = normalizeForMatch(l);
      if (n.isEmpty) continue;
      map.putIfAbsent(n, () => <String>{}).add(o.isco);
      for (final w in n.split(' ')) {
        spread.putIfAbsent(w, () => <String>{}).add(o.isco);
      }
    }
  }
  // single generic words are removed from the index (curated entries below can still name them)
  map.removeWhere(
    (k, _) => !k.contains(' ') && (spread[k]?.length ?? 0) >= _genericSpread,
  );
  // curated names win over ESCO for the same text: they exist because the ESCO name was too generic or missing
  for (final e in _curated.entries) {
    for (final l in e.value) {
      map[normalizeForMatch(l)] = {e.key};
    }
  }
  return _index = map;
}

final Map<String, OccupationMatch> _memo = {};
final Map<String, List<OccupationMatch>> _mentionsMemo = {};

/// The occupation group(s) named by the LONGEST known name inside [text] (a profession the person wrote); none when no name is known.
OccupationMatch occupationOf(String text) {
  final key = normalizeForMatch(text);
  if (key.isEmpty) return OccupationMatch.none;
  final hit = _memo[key];
  if (hit != null) return hit;
  final m = mentionsIn(text);
  // the longest mention; ties keep the first one written
  var best = OccupationMatch.none;
  for (final x in m) {
    if (x.words > best.words) best = x;
  }
  if (_memo.length > 4000) _memo.clear();
  return _memo[key] = best;
}

/// Every occupation a title NAMES, as separate mentions: longest names first and a word belongs to one mention only, so in "Engenheiro
/// Eletricista" the name "eletricista" is part of the engineer's and is not a second occupation, while "Physiotherapist / Occupational
/// Therapist" names two.
List<OccupationMatch> mentionsIn(String text) {
  final key = normalizeForMatch(text);
  if (key.isEmpty) return const [];
  final hit = _mentionsMemo[key];
  if (hit != null) return hit;
  final words = key.split(' ');
  final labels = _labels();
  final used = List<bool>.filled(words.length, false);
  final out = <OccupationMatch>[];
  for (var n = words.length < 6 ? words.length : 6; n >= 1; n--) {
    for (var i = 0; i + n <= words.length; i++) {
      var free = true;
      for (var k = i; k < i + n; k++) {
        if (used[k]) {
          free = false;
          break;
        }
      }
      if (!free) continue;
      final c = labels[words.sublist(i, i + n).join(' ')];
      if (c == null) continue;
      for (var k = i; k < i + n; k++) {
        used[k] = true;
      }
      out.add(
        OccupationMatch(
          c,
          n,
          curated: _curatedKeys.contains(words.sublist(i, i + n).join(' ')),
        ),
      );
    }
  }
  if (_mentionsMemo.length > 4000) _mentionsMemo.clear();
  return _mentionsMemo[key] = out;
}

/// True when the title names an occupation of its own and NONE of the occupations it names is the person's (or in its sub-major group): the words
/// of the profession are then only a modifier of something else ("Engenheiro Eletricista" for an electrician, "Auxiliar de enfermagem" for a
/// nurse). Unknown on either side is never a conflict.
bool titleNamesOtherOccupation(
  OccupationMatch person,
  String title, {
  int minWords = 1,
}) {
  if (!person.known) return false;
  final mentions = mentionsIn(title);
  if (mentions.isEmpty) return false;
  // a one-word ESCO name next to a curated synonym ("Accountant" for "Buchhalter") is the same trade in another language, not a modifier;
  // a multi-word name, or a curated one ("Pflegehelfer"), is a different occupation
  if (!mentions.any((m) => m.words >= minWords || m.curated)) return false;
  for (final m in mentions) {
    // the same sub-major group is still compatible ("Eletricista industrial" is an electrical fitter, next to the building electrician): the
    // conflict is a different kind of occupation altogether
    if (relationOf(person.codes, m.codes) != Relation.none) return false;
  }
  return true;
}

enum Relation {
  /// At least one unit group in common: the same occupation group.
  sameGroup,

  /// Different groups of one narrow neighbourhood (software and application developers).
  related,

  /// Only the major area is shared (both are "health professionals"): not a recommendation on its own.
  areaOnly,

  /// Nothing in common, or unknown.
  none,
}

Relation relationOf(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return Relation.none;
  if (a.any(b.contains)) return Relation.sameGroup;
  for (final c in _relatedClusters) {
    if (a.any(c.contains) && b.any(c.contains)) return Relation.related;
  }
  if (a.any((x) => b.any((y) => x.substring(0, 2) == y.substring(0, 2)))) {
    return Relation.areaOnly;
  }
  return Relation.none;
}
