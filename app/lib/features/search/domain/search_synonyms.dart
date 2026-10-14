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
    'kinésithérapeute',
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
    // not the bare stem "pflege": it is also Rechtspfleger (court clerk), Tierpfleger (zookeeper), Denkmalpflege, Grünpflege
    'krankenpfleg',
    'krankenschwester',
    'pflegefach',
    'pflegekraft',
    'altenpfleg',
    'pflegehelf',
    'pflegeassist',
    'sjuksköterska',
    'infirmier',
    'infirmière',
    // Czech: "zdravotní sestra" / "všeobecná sestra" (never the bare "sestra", which is also a sister)
    'zdravotní sestr',
    'všeobecná sestr',
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
  [
    'professor',
    'professora',
    'docente',
    'teacher',
    'lehrer',
    'lärare',
    'enseignant',
    'učitel',
    '教師',
  ],
  [
    'motorista',
    'conductor',
    'driver',
    'fahrer',
    'chaufför',
    'chauffeur',
    'řidič',
  ],
  ['vendedor', 'vendedora', 'sales', 'verkäufer', 'säljare'],
  ['contador', 'contadora', 'accountant', 'buchhalter'],
  ['engenheir', 'ingenier', 'engineer', 'ingenieur', 'ingenjör'],
  ['desenvolvedor', 'desarrollador', 'developer', 'entwickler', 'utvecklare'],
  [
    'eletricista',
    'electricista',
    'electrician',
    'elektriker',
    'électricien',
    'elektricien',
    'elektrikář',
  ],
  [
    'soldador',
    'soldadora',
    'welder',
    'schweißer',
    'schweisser',
    'svetsare',
    'soudeur',
    'svářeč',
  ],
  ['cozinheir', 'cocinero', 'cuisinier', 'köchin', 'cook', 'kuchař'],
  // waiting staff (Brazilian "garçom" is not an ESCO label: ESCO Portuguese uses "empregado de mesa")
  [
    'garçom',
    'garçonete',
    'empregado de mesa',
    'waiter',
    'waitress',
    'camarero',
    'camarera',
    'mesero',
    'kellner',
    'servitör',
    'serveur',
    'serveuse',
    'číšník',
    'servírka',
  ],
  // construction labour: the general worker names only (masons, carpenters... are their own occupations)
  [
    'trabalhador de construção',
    'servente de obras',
    'construction worker',
    'construction labourer',
    'construction laborer',
    'peón de construcción',
    'obrero de construcción',
    'bauarbeiter',
    'bauhelfer',
    'byggnadsarbetare',
    'ouvrier du bâtiment',
    'stavební dělník',
  ],
  // warehouse work: specific names only ("lager" alone is also beer, camp, bearing)
  [
    'trabalhador de armazém',
    'auxiliar de armazém',
    'warehouse worker',
    'warehouse operative',
    'mozo de almacén',
    'lagerarbeiter',
    'lagermitarbeiter',
    'lagerist',
    'lagerarbetare',
    'magasinier',
    'skladník',
  ],
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
