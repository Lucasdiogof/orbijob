/// Equivalent profession names across the languages the catalogue holds (Portuguese, Spanish, English, German).
///
/// Most listings come from English and German sources, so a person searching "fisioterapeuta" would otherwise find
/// nothing. A search term that contains one of these groups' words is widened to the other words of the group, matched
/// in the TITLE only. Nothing is translated or rewritten: the listing keeps its original text, the query just looks for
/// the same profession under its other names. Every entry is a lower-case fragment without commas, parentheses, quotes
/// or wildcards (checked by the tests), so it can be placed in a PostgREST filter as is.
const List<List<String>> _groups = [
  [
    'fisioterap',
    'physiotherap',
    'physical therap',
    'kinesiolog',
    'fysioterapeut',
    'sjukgymnast',
    '物理治療',
  ],
  [
    'pélvic',
    'pelvic',
    'beckenboden',
    'assoalho pélvico',
    'piso pélvico',
    'bäckenbotten',
  ],
  ['uroginecol', 'urogynecol', 'urogynaecol'],
  [
    'enfermeir',
    'enfermagem',
    'enfermer',
    'nurse',
    'nursing',
    'pflege',
    'sjuksköterska',
    '護理',
  ],
  ['médico', 'médica', 'physician', 'arzt', 'ärztin', 'läkare'],
  ['psicólog', 'psicolog', 'psycholog', 'psykolog'],
  [
    'terapeuta ocupacional',
    'terapia ocupacional',
    'occupational therap',
    'ergotherap',
    'arbetsterapeut',
  ],
  ['nutricionista', 'nutritionist', 'dietitian', 'dietician', 'dietist'],
  ['dentista', 'odontolog', 'dentist', 'zahnarzt', 'tandläkare'],
  ['farmacêutic', 'farmacéutic', 'pharmacist', 'apotheker', 'apotekare'],
  [
    'fonoaudiólog',
    'fonoaudiolog',
    'speech therap',
    'speech-language',
    'logopäd',
    'logoped',
  ],
  ['radiolog', 'radiographer'],
  ['professor', 'professora', 'docente', 'teacher', 'lehrer', 'lärare', '教師'],
  ['motorista', 'conductor', 'driver', 'fahrer', 'chaufför'],
  ['vendedor', 'vendedora', 'sales', 'verkäufer', 'säljare'],
  ['contador', 'contadora', 'accountant', 'buchhalter'],
  ['engenheir', 'ingenier', 'engineer', 'ingenieur', 'ingenjör'],
  ['desenvolvedor', 'desarrollador', 'developer', 'entwickler', 'utvecklare'],
  [
    'advogad',
    'abogad',
    'lawyer',
    'attorney',
    'rechtsanwalt',
    'jurist',
    'advokat',
  ],
];

/// The other names of every profession [term] mentions, without the fragments [term] already contains.
List<String> titleSynonyms(String term) {
  final t = term.toLowerCase();
  final out = <String>{};
  for (final g in _groups) {
    if (g.any(t.contains)) out.addAll(g.where((w) => !t.contains(w)));
  }
  return out.toList();
}

/// Exposed for the tests (filter-safety check).
List<List<String>> get synonymGroups => _groups;
