/// Contract and seniority terms sources write in their own language ("Unbefristeter arbeitsvertrag, berufserfahren"), shown in the
/// interface language through a fixed table: structured terms are mapped, not freely translated, so the meaning cannot drift.
/// Anything the table does not know returns null and the caller falls back to the on-device translation or the original text.
library;

enum _Term {
  permanent,
  fixedTerm,
  fullTime,
  partTime,
  internship,
  apprenticeship,
  freelance,
  temporary,
  experienced,
  entryLevel,
  volunteer,
}

// Order matters: `unbefristet` (permanent) must be tested before `befristet` (fixed term).
final _patterns = <(RegExp, _Term)>[
  (
    RegExp(
      r'unbefristet|permanent|indefinid|tempo indeterminado|prazo indeterminado|\bcdi\b|tillsvidare|toujours|onbepaalde|vast contract|tidsubegr|toistaiseksi',
    ),
    _Term.permanent,
  ),
  (
    RegExp(
      r'befristet|fixed.?term|\bcdd\b|determinad|visstid|bepaalde|durée déterminée|tidsbegr|määräaikai',
    ),
    _Term.fixedTerm,
  ),
  (
    RegExp(
      r'vollzeit|full.?time|temps plein|tiempo completo|jornada completa|heltid|voltijd|tempo integral|kokoaika|plein temps',
    ),
    _Term.fullTime,
  ),
  (
    RegExp(
      r'teilzeit|part.?time|temps partiel|tiempo parcial|jornada parcial|deltid|deeltijd|tempo parcial|osa-aika',
    ),
    _Term.partTime,
  ),
  (
    RegExp(
      r'praktikum|internship|\bstage\b|pr[aá]cticas|praktik|est[aá]gio|stagiair',
    ),
    _Term.internship,
  ),
  (
    RegExp(
      r'ausbildung|apprenti|alternance|aprendiz|l[aä]rling|leerling|lärlingsplats',
    ),
    _Term.apprenticeship,
  ),
  (
    RegExp(
      r'freelance|freiberuf|selbst[aä]ndig|contractor|aut[oó]nomo|zzp|frilans',
    ),
    _Term.freelance,
  ),
  (
    RegExp(
      r'zeitarbeit|temporary|temporal\b|tempor[aá]rio|int[eé]rim|vikariat|uitzend',
    ),
    _Term.temporary,
  ),
  (
    RegExp(
      r'berufserfahren|experienced|exp[eé]riment|con experiencia|experiente',
    ),
    _Term.experienced,
  ),
  (
    RegExp(
      r'berufseinsteiger|entry.?level|d[eé]butant|sin experiencia|iniciante',
    ),
    _Term.entryLevel,
  ),
  (RegExp(r'ehrenamt|volunteer|b[eé]n[eé]vol|voluntari'), _Term.volunteer),
  // the word "contract" alone says nothing more than the terms around it; it is dropped when something else matched
];

final _labels = <String, Map<_Term, String>>{
  'pt': {
    _Term.permanent: 'Prazo indeterminado',
    _Term.fixedTerm: 'Prazo determinado',
    _Term.fullTime: 'Tempo integral',
    _Term.partTime: 'Meio período',
    _Term.internship: 'Estágio',
    _Term.apprenticeship: 'Aprendizagem',
    _Term.freelance: 'Autônomo',
    _Term.temporary: 'Temporário',
    _Term.experienced: 'Com experiência',
    _Term.entryLevel: 'Iniciante',
    _Term.volunteer: 'Voluntariado',
  },
  'en': {
    _Term.permanent: 'Permanent',
    _Term.fixedTerm: 'Fixed term',
    _Term.fullTime: 'Full-time',
    _Term.partTime: 'Part-time',
    _Term.internship: 'Internship',
    _Term.apprenticeship: 'Apprenticeship',
    _Term.freelance: 'Freelance',
    _Term.temporary: 'Temporary',
    _Term.experienced: 'Experienced',
    _Term.entryLevel: 'Entry level',
    _Term.volunteer: 'Volunteer',
  },
  'es': {
    _Term.permanent: 'Indefinido',
    _Term.fixedTerm: 'Duración determinada',
    _Term.fullTime: 'Jornada completa',
    _Term.partTime: 'Media jornada',
    _Term.internship: 'Prácticas',
    _Term.apprenticeship: 'Aprendizaje',
    _Term.freelance: 'Autónomo',
    _Term.temporary: 'Temporal',
    _Term.experienced: 'Con experiencia',
    _Term.entryLevel: 'Sin experiencia',
    _Term.volunteer: 'Voluntariado',
  },
};

/// The contract/seniority [raw] text in [ui] (`pt`, `en`, `es`), or null when any part of it is not in the table.
/// Text already in the interface language is returned as it is by the callers (they compare the language first).
String? localizedContract(String raw, String ui) {
  final labels = _labels[ui];
  if (labels == null) return null;
  final parts = raw
      .split(RegExp(r'[,;/|·•]|\s[-–—]\s'))
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty);
  final terms = <_Term>[];
  for (final part in parts) {
    final hit = _patterns.where((p) => p.$1.hasMatch(part)).map((p) => p.$2);
    if (hit.isEmpty) return null;
    // "Vollzeit, unbefristet" in one part keeps both terms; "unbefristet" never also counts as fixed term
    final first = hit.first;
    for (final t in {
      if (first == _Term.permanent)
        ...hit.where((t) => t != _Term.fixedTerm)
      else
        ...hit,
    }) {
      if (!terms.contains(t)) terms.add(t);
    }
  }
  if (terms.isEmpty) return null;
  return terms.map((t) => labels[t]!).join(', ');
}
