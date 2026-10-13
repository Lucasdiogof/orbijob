/// Turns the plain text of a résumé into *suggestions* for the profile. Nothing here invents data: every value is a piece of
/// the text (or a normalisation of it, such as a date or a language code). The app always shows the suggestions for review and
/// correction before anything is saved. Section headings are understood in Portuguese, English and Spanish.
library;

class SuggestedExperience {
  const SuggestedExperience({
    this.title = '',
    this.company = '',
    this.start,
    this.end,
    this.description,
  });
  final String title;
  final String company;
  final DateTime? start;

  /// Null with a [start] means "current job".
  final DateTime? end;
  final String? description;
}

class SuggestedEducation {
  const SuggestedEducation({
    this.institution = '',
    this.degree,
    this.field,
    this.start,
    this.end,
  });
  final String institution;
  final String? degree;
  final String? field;
  final DateTime? start;
  final DateTime? end;
}

class SuggestedLanguage {
  const SuggestedLanguage(this.code, [this.level]);

  /// ISO 639-1 code.
  final String code;
  final String? level;
}

class ResumeSuggestion {
  const ResumeSuggestion({
    this.name,
    this.headline,
    this.summary,
    this.email,
    this.phone,
    this.city,
    this.country,
    this.links = const [],
    this.skills = const [],
    this.languages = const [],
    this.experiences = const [],
    this.education = const [],
  });

  final String? name;
  final String? headline;
  final String? summary;
  final String? email;
  final String? phone;
  final String? city;

  /// ISO 3166-1 alpha-2, only when the text names a country we recognise.
  final String? country;
  final List<String> links;
  final List<String> skills;
  final List<SuggestedLanguage> languages;
  final List<SuggestedExperience> experiences;
  final List<SuggestedEducation> education;

  bool get isEmpty =>
      name == null &&
      headline == null &&
      summary == null &&
      email == null &&
      phone == null &&
      city == null &&
      country == null &&
      links.isEmpty &&
      skills.isEmpty &&
      languages.isEmpty &&
      experiences.isEmpty &&
      education.isEmpty;
}

// ---------------------------------------------------------------------------------------------------------------------

String _fold(String s) {
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

enum _Section { none, summary, experience, education, skills, languages, other }

const _headings = <_Section, List<String>>{
  _Section.summary: [
    'resumo',
    'resumo profissional',
    'perfil',
    'perfil profissional',
    'objetivo',
    'objetivo profissional',
    'sobre mim',
    'sobre',
    'summary',
    'professional summary',
    'profile',
    'professional profile',
    'about',
    'about me',
    'objective',
    'career objective',
    'resumen',
    'resumen profesional',
    'sobre mi',
    'perfil personal',
  ],
  _Section.experience: [
    'experiencia',
    'experiencia profissional',
    'experiencias profissionais',
    'experiencia profesional',
    'experiencia laboral',
    'historico profissional',
    'trajetoria profissional',
    'work experience',
    'professional experience',
    'experience',
    'employment',
    'employment history',
    'work history',
    'career history',
    'relevant experience',
  ],
  _Section.education: [
    'formacao',
    'formacao academica',
    'formacao e cursos',
    'educacao',
    'escolaridade',
    'education',
    'academic background',
    'academic qualifications',
    'education and training',
    'formacion',
    'formacion academica',
    'educacion',
    'estudios',
  ],
  _Section.skills: [
    'habilidades',
    'habilidades tecnicas',
    'competencias',
    'competencias tecnicas',
    'conhecimentos',
    'tecnologias',
    'skills',
    'technical skills',
    'key skills',
    'core skills',
    'core competencies',
    'competencies',
    'aptitudes',
    'conocimientos',
    'competencias clave',
  ],
  _Section.languages: [
    'idiomas',
    'languages',
    'lenguas',
    'linguas',
    'language skills',
  ],
  _Section.other: [
    'cursos',
    'cursos e certificacoes',
    'certificacoes',
    'certificados',
    'certifications',
    'courses',
    'projetos',
    'projects',
    'publicacoes',
    'publications',
    'premios',
    'awards',
    'honors',
    'voluntariado',
    'volunteering',
    'volunteer experience',
    'referencias',
    'references',
    'interesses',
    'interests',
    'hobbies',
    'informacoes adicionais',
    'additional information',
    'cursos y certificaciones',
    'certificaciones',
    'proyectos',
    'intereses',
    'dados pessoais',
    'personal details',
    'datos personales',
    'contato',
    'contact',
    'contacto',
    'licencas',
    'licenses',
    'atividades extracurriculares',
  ],
};

final _headingIndex = <String, _Section>{
  for (final e in _headings.entries)
    for (final k in e.value) k: e.key,
};

_Section _headingOf(String line) {
  if (line.length > 48) return _Section.none;
  var t = _fold(line).replaceAll(RegExp(r'[:\-–—_.•·|]+$'), '').trim();
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  return _headingIndex[t] ?? _Section.none;
}

// ---- dates --------------------------------------------------------------------------------------------------------

const _months = <String, int>{
  'jan': 1,
  'january': 1,
  'janeiro': 1,
  'enero': 1,
  'ene': 1,
  'feb': 2,
  'february': 2,
  'fev': 2,
  'fevereiro': 2,
  'febrero': 2,
  'mar': 3,
  'march': 3,
  'marco': 3,
  'marzo': 3,
  'apr': 4,
  'april': 4,
  'abr': 4,
  'abril': 4,
  'may': 5,
  'mai': 5,
  'maio': 5,
  'mayo': 5,
  'jun': 6,
  'june': 6,
  'junho': 6,
  'junio': 6,
  'jul': 7,
  'july': 7,
  'julho': 7,
  'julio': 7,
  'aug': 8,
  'august': 8,
  'ago': 8,
  'agosto': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'set': 9,
  'setembro': 9,
  'septiembre': 9,
  'setiembre': 9,
  'oct': 10,
  'october': 10,
  'out': 10,
  'outubro': 10,
  'octubre': 10,
  'nov': 11,
  'november': 11,
  'novembro': 11,
  'noviembre': 11,
  'dec': 12,
  'december': 12,
  'dez': 12,
  'dezembro': 12,
  'dic': 12,
  'diciembre': 12,
};

const _presentWords =
    r'(?:present|presente|current|currently|now|ongoing|atual|atualmente|hoje|actual|actualidad|actualmente|la fecha|o momento)\w*';

final _datePart =
    r'(?:(?:\d{1,2}[\/\-.]\d{4})|(?:[A-Za-zÀ-ÿ]{3,10}\.?\s+\d{4})|(?:\d{4}))';

final _rangeRe = RegExp(
  '($_datePart)\\s*(?:-|–|—|to|a|até|ate|hasta|al)\\s*($_datePart|$_presentWords)',
  caseSensitive: false,
);

DateTime? _parseDate(String raw) {
  final t = _fold(raw.trim().replaceAll('.', ''));
  final num1 = RegExp(r'^(\d{1,2})[\/\-](\d{4})$').firstMatch(t);
  if (num1 != null) {
    final m = int.parse(num1.group(1)!);
    if (m >= 1 && m <= 12) return DateTime(int.parse(num1.group(2)!), m);
    return null;
  }
  final named = RegExp(r'^([a-z]{3,10})\s+(\d{4})$').firstMatch(t);
  if (named != null) {
    final m = _months[named.group(1)!];
    if (m != null) return DateTime(int.parse(named.group(2)!), m);
    return null;
  }
  final y = RegExp(r'^(\d{4})$').firstMatch(t);
  if (y != null) {
    final yy = int.parse(y.group(1)!);
    if (yy >= 1950 && yy <= DateTime.now().year + 1) return DateTime(yy);
  }
  return null;
}

class _Range {
  _Range(this.start, this.end, this.current, this.match);
  final DateTime? start;
  final DateTime? end;
  final bool current;
  final RegExpMatch match;
}

_Range? _rangeIn(String line) {
  for (final m in _rangeRe.allMatches(line)) {
    final a = _parseDate(m.group(1)!);
    if (a == null) continue;
    final endRaw = m.group(2)!;
    if (RegExp(
      '^$_presentWords\$',
      caseSensitive: false,
    ).hasMatch(endRaw.trim())) {
      return _Range(a, null, true, m);
    }
    final b = _parseDate(endRaw);
    if (b == null) continue;
    if (b.isBefore(a)) continue;
    return _Range(a, b, false, m);
  }
  return null;
}

// ---- contact ------------------------------------------------------------------------------------------------------

final _emailRe = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
final _urlRe = RegExp(
  r'(?:https?:\/\/|www\.)[^\s,;|·•]+|(?:linkedin\.com|github\.com|gitlab\.com)\/[^\s,;|·•]+',
  caseSensitive: false,
);
final _phoneRe = RegExp(
  r'(?:\+\s?\d{1,3}[\s.\-]?)?(?:\(?\d{2,4}\)?[\s.\-]?)?\d{3,5}[\s.\-]?\d{3,5}(?:[\s.\-]?\d{2,4})?',
);

String? _phoneIn(String line) {
  final noEmail = line.replaceAll(_emailRe, ' ').replaceAll(_urlRe, ' ');
  if (_rangeIn(noEmail) != null) {
    // a date range is not a phone number
    final cleaned = noEmail.replaceAll(_rangeRe, ' ');
    return _firstPhone(cleaned);
  }
  return _firstPhone(noEmail);
}

String? _firstPhone(String s) {
  for (final m in _phoneRe.allMatches(s)) {
    final t = m.group(0)!.trim();
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8 || digits.length > 15) continue;
    if (RegExp(r'^(19|20)\d{2}$').hasMatch(digits)) continue;
    return t;
  }
  return null;
}

const _countries = <String, String>{
  'brasil': 'BR',
  'brazil': 'BR',
  'portugal': 'PT',
  'estados unidos': 'US',
  'united states': 'US',
  'usa': 'US',
  'eua': 'US',
  'u.s.a.': 'US',
  'reino unido': 'GB',
  'united kingdom': 'GB',
  'uk': 'GB',
  'inglaterra': 'GB',
  'espanha': 'ES',
  'espana': 'ES',
  'spain': 'ES',
  'franca': 'FR',
  'francia': 'FR',
  'france': 'FR',
  'alemanha': 'DE',
  'alemania': 'DE',
  'germany': 'DE',
  'deutschland': 'DE',
  'italia': 'IT',
  'italy': 'IT',
  'canada': 'CA',
  'mexico': 'MX',
  'argentina': 'AR',
  'chile': 'CL',
  'colombia': 'CO',
  'peru': 'PE',
  'uruguai': 'UY',
  'uruguay': 'UY',
  'paraguai': 'PY',
  'paraguay': 'PY',
  'irlanda': 'IE',
  'ireland': 'IE',
  'holanda': 'NL',
  'paises baixos': 'NL',
  'netherlands': 'NL',
  'suica': 'CH',
  'suiza': 'CH',
  'switzerland': 'CH',
  'suecia': 'SE',
  'sweden': 'SE',
  'sverige': 'SE',
  'noruega': 'NO',
  'norway': 'NO',
  'dinamarca': 'DK',
  'denmark': 'DK',
  'finlandia': 'FI',
  'finland': 'FI',
  'australia': 'AU',
  'nova zelandia': 'NZ',
  'nueva zelanda': 'NZ',
  'new zealand': 'NZ',
  'japao': 'JP',
  'japon': 'JP',
  'japan': 'JP',
  'china': 'CN',
  'india': 'IN',
  'singapura': 'SG',
  'singapur': 'SG',
  'singapore': 'SG',
  'africa do sul': 'ZA',
  'sudafrica': 'ZA',
  'south africa': 'ZA',
  'emirados arabes unidos': 'AE',
  'united arab emirates': 'AE',
  'uae': 'AE',
  'taiwan': 'TW',
};

// ---- languages ----------------------------------------------------------------------------------------------------

const _languageNames = <String, String>{
  'portugues': 'pt',
  'portuguese': 'pt',
  'portugues brasileiro': 'pt',
  'ingles': 'en',
  'english': 'en',
  'ingles americano': 'en',
  'espanhol': 'es',
  'espanol': 'es',
  'spanish': 'es',
  'castellano': 'es',
  'frances': 'fr',
  'french': 'fr',
  'francais': 'fr',
  'alemao': 'de',
  'aleman': 'de',
  'german': 'de',
  'deutsch': 'de',
  'italiano': 'it',
  'italian': 'it',
  'chines': 'zh',
  'chino': 'zh',
  'chinese': 'zh',
  'mandarim': 'zh',
  'mandarin': 'zh',
  'japones': 'ja',
  'japanese': 'ja',
  'coreano': 'ko',
  'korean': 'ko',
  'russo': 'ru',
  'ruso': 'ru',
  'russian': 'ru',
  'arabe': 'ar',
  'arabic': 'ar',
  'hindi': 'hi',
  'holandes': 'nl',
  'neerlandes': 'nl',
  'dutch': 'nl',
  'sueco': 'sv',
  'swedish': 'sv',
  'svenska': 'sv',
  'turco': 'tr',
  'turkish': 'tr',
  'polones': 'pl',
  'polaco': 'pl',
  'polish': 'pl',
  'ucraniano': 'uk',
  'ukrainian': 'uk',
  'catalao': 'ca',
  'catalan': 'ca',
  'libras': 'bzs',
};

// ---- the parser ---------------------------------------------------------------------------------------------------

bool _isBullet(String l) => RegExp(r'^[•·▪■◦\-–—*►➢✓]\s*\S').hasMatch(l);

String _unbullet(String l) =>
    l.replaceFirst(RegExp(r'^[•·▪■◦\-–—*►➢✓]\s*'), '').trim();

bool _looksLikeName(String l) {
  if (l.length < 4 || l.length > 60) return false;
  if (RegExp(r'[\d@/:|]').hasMatch(l)) return false;
  if (_headingOf(l) != _Section.none) return false;
  final words = l.split(RegExp(r'\s+'));
  if (words.length < 2 || words.length > 6) return false;
  final up = RegExp(r'^[A-ZÀ-Ý][A-Za-zÀ-ÿ’.\-]*$');
  final small = {
    'da',
    'de',
    'do',
    'dos',
    'das',
    'del',
    'la',
    'van',
    'von',
    'y',
    'e',
    'di',
    'du',
    'bin',
    'al',
  };
  var caps = 0;
  for (final w in words) {
    if (up.hasMatch(w)) {
      caps++;
    } else if (!small.contains(w.toLowerCase())) {
      return false;
    }
  }
  return caps >= 2;
}

bool _isContactLine(String l) =>
    _emailRe.hasMatch(l) || _urlRe.hasMatch(l) || _phoneIn(l) != null;

final _companyHint = RegExp(
  r'\b(inc|ltd|ltda|llc|corp|corporation|gmbh|s\.?a\.?|sl|s\.l\.|ab|oy|bv|pty|co\.|company|group|grupo|technologies|tecnologia|labs|hospital|cl[ií]nica|clinic|universidade|university|universidad|faculdade|college|instituto|institute|escola|school|empresa|consultoria|consulting|solutions|studio|bank|banco)\b',
  caseSensitive: false,
);

final _schoolHint = RegExp(
  r'\b(universidade|university|universidad|faculdade|facultad|college|instituto|institute|escola|school|senai|senac|centro universit|politecnico|polytechnic|academy|academia|hogeschool|universit[aä]t|uni)\b',
  caseSensitive: false,
);

// A dash, bar or "@" separates two parts; words such as "at" or "em" only count when no such mark exists (a degree like
// "Bacharelado em Fisioterapia — Universidade X" must split at the dash, not at "em").
final _strongSep = RegExp(r'\s+[—–-]\s+|\s*[—–|@]\s*');
final _weakSep = RegExp(
  r'\s+(?:at|em|en|na|no|para|for)\s+',
  caseSensitive: false,
);

(String, String)? _split2(String one) {
  for (final re in [_strongSep, _weakSep]) {
    final m = re.firstMatch(one);
    if (m != null) {
      final left = one.substring(0, m.start).trim();
      final right = one.substring(m.end).trim();
      if (left.isNotEmpty && right.isNotEmpty) return (left, right);
    }
  }
  return null;
}

(String, String) _splitTitleCompany(List<String> header) {
  final lines = header.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (lines.isEmpty) return ('', '');
  if (lines.length >= 2) {
    final a = lines[0];
    final b = lines[1];
    final aCo = _companyHint.hasMatch(a);
    final bCo = _companyHint.hasMatch(b);
    if (aCo && !bCo) return (b, a);
    return (a, b);
  }
  final one = lines.first;
  final two = _split2(one);
  if (two != null) {
    final (left, right) = two;
    if (_companyHint.hasMatch(left) && !_companyHint.hasMatch(right)) {
      return (right, left);
    }
    return (left, _firstSegment(right));
  }
  final comma = one
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (comma.length >= 2) return (comma[0], comma[1]);
  return (one, '');
}

String _firstSegment(String s) => s.split(RegExp(r'\s*,\s*')).first.trim();

ResumeSuggestion parseResumeText(String text) {
  final lines = [
    for (final l in text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  if (lines.isEmpty) return const ResumeSuggestion();

  // --- split in sections
  final sections = <_Section, List<String>>{};
  final head = <String>[];
  var cur = _Section.none;
  for (final l in lines) {
    final h = _headingOf(l);
    if (h != _Section.none) {
      cur = h;
      sections.putIfAbsent(h, () => []);
      continue;
    }
    if (cur == _Section.none) {
      head.add(l);
    } else {
      sections[cur]!.add(l);
    }
  }

  // --- contact & identity from the whole text (the head block first)
  String? email;
  String? phone;
  final links = <String>[];
  for (final l in [...head, ...?sections[_Section.other]]) {
    email ??= _emailRe.firstMatch(l)?.group(0);
    phone ??= _phoneIn(l);
    for (final m in _urlRe.allMatches(l)) {
      final u = m.group(0)!.replaceAll(RegExp(r'[.,;)]+$'), '');
      if (!links.contains(u)) links.add(u);
    }
  }
  email ??= _emailRe.firstMatch(text)?.group(0);

  String? name;
  String? headline;
  var nameIdx = -1;
  for (var i = 0; i < head.length && i < 6; i++) {
    if (_looksLikeName(head[i])) {
      name = head[i];
      nameIdx = i;
      break;
    }
  }
  if (nameIdx >= 0) {
    for (var i = nameIdx + 1; i < head.length && i < nameIdx + 4; i++) {
      final l = head[i];
      if (_isContactLine(l) || l.length > 90 || _looksLikeLocation(l)) continue;
      if (RegExp(r'\d{3,}').hasMatch(l)) continue;
      headline = l;
      break;
    }
  }

  // --- location from the head block
  String? city;
  String? country;
  for (var i = 0; i < head.length; i++) {
    // a contact line may be wrapped by the page width: also try it joined with the next line
    final alone = _locationIn(head[i]);
    final joined = i + 1 < head.length && head[i].endsWith(',')
        ? _locationIn('${head[i]} ${head[i + 1]}')
        : null;
    final loc = (joined != null && joined.$2 != null && alone?.$2 == null)
        ? joined
        : (alone ?? joined);
    if (loc != null) {
      city = loc.$1;
      country = loc.$2;
      break;
    }
  }

  // --- summary
  String? summary;
  final sum = sections[_Section.summary];
  if (sum != null && sum.isNotEmpty) {
    summary = sum.map(_unbullet).join(' ').trim();
    if (summary.length > 4000) summary = summary.substring(0, 4000);
    if (summary.isEmpty) summary = null;
  }

  return ResumeSuggestion(
    name: name,
    headline: headline,
    summary: summary,
    email: email,
    phone: phone,
    city: city,
    country: country,
    links: links.take(5).toList(),
    skills: _skills(sections[_Section.skills] ?? const []),
    languages: _languages(sections[_Section.languages] ?? const []),
    experiences: _experiences(sections[_Section.experience] ?? const []),
    education: _education(sections[_Section.education] ?? const []),
  );
}

bool _looksLikeLocation(String l) =>
    _locationIn(l) != null && !_isContactLine(l) ||
    (_locationIn(l) != null &&
        l.split(RegExp(r'[·|•]')).length <= 2 &&
        !_emailRe.hasMatch(l));

/// "City, State, Country" taken from one of the separated parts of a contact line; the country only when we know it.
(String?, String?)? _locationIn(String line) {
  final parts = line
      .split(RegExp(r'\s*[·|•]\s*|\s+[–—-]\s+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty);
  for (final p in parts) {
    if (_emailRe.hasMatch(p) || _urlRe.hasMatch(p) || _phoneIn(p) != null) {
      continue;
    }
    if (RegExp(r'\d').hasMatch(p)) continue;
    final segs = p
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (segs.isEmpty || p.length > 70) continue;
    final last = _fold(segs.last);
    final cc = _countries[last];
    if (cc != null) {
      return (segs.length >= 2 ? segs.first : null, cc);
    }
    if (segs.length >= 2 &&
        segs.every((s) => RegExp(r'^[A-Za-zÀ-ÿ .\x27-]{2,40}$').hasMatch(s))) {
      // "São Paulo, SP": a city and a region, no recognised country
      if (segs.last.length <= 3 || segs.length >= 2) return (segs.first, null);
    }
  }
  return null;
}

List<String> _skills(List<String> lines) {
  final out = <String>[];
  for (var l in lines) {
    l = _unbullet(l);
    final colon = l.indexOf(':');
    if (colon > 0 && colon < 40) l = l.substring(colon + 1);
    for (final part in l.split(RegExp(r'[,;|•·●▪]|\s{2,}'))) {
      final s = _unbullet(part)
          .replaceAll(RegExp(r'^[\-–]+|[\-–]+$'), '')
          .trim();
      if (s.length < 2 || s.length > 60) continue;
      if (!RegExp(r'\p{L}', unicode: true).hasMatch(s)) continue;
      if (out.any((e) => e.toLowerCase() == s.toLowerCase())) continue;
      out.add(s);
      if (out.length >= 60) return out;
    }
  }
  return out;
}

List<SuggestedLanguage> _languages(List<String> lines) {
  final out = <SuggestedLanguage>[];
  for (final l in lines) {
    for (final part in _unbullet(l).split(RegExp(r'[,;|•·]'))) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final m = RegExp(r'^([A-Za-zÀ-ÿ ]{3,30}?)\s*(?:[\(:\-–—]\s*(.+?)\)?)?$')
          .firstMatch(p);
      if (m == null) continue;
      final code = _languageNames[_fold(m.group(1)!.trim())];
      if (code == null) continue;
      if (out.any((e) => e.code == code)) continue;
      final level = m.group(2)?.replaceAll(RegExp(r'[()]'), '').trim();
      out.add(
        SuggestedLanguage(code, level == null || level.isEmpty ? null : level),
      );
    }
  }
  return out;
}

// A header line (title, company, degree) is short and is not a sentence; a trailing period is fine only after an abbreviation
// such as "Inc." or "Ltda.".
bool _isHeaderish(String l) =>
    !_isBullet(l) &&
    l.length <= 110 &&
    (!RegExp(r'[.!?]$').hasMatch(l) ||
        RegExp(
          r'\b(inc|ltd|ltda|llc|corp|co|sa|s\.a|gmbh|pty|bv|ab|plc|jr|sr|eireli|me)\.$',
          caseSensitive: false,
        ).hasMatch(l));

List<SuggestedExperience> _experiences(List<String> lines) {
  final anchors = <int>[];
  final ranges = <int, _Range>{};
  for (var i = 0; i < lines.length; i++) {
    final r = _rangeIn(lines[i]);
    if (r != null && !_isBullet(lines[i])) {
      anchors.add(i);
      ranges[i] = r;
    }
  }
  if (anchors.isEmpty) return const [];

  // date-first layout: the date line comes before the title line of the same entry
  final dateFirst =
      anchors.first == 0 ||
      lines.sublist(0, anchors.first).every((l) => !_isHeaderish(l));

  final out = <SuggestedExperience>[];
  for (var k = 0; k < anchors.length; k++) {
    final a = anchors[k];
    final r = ranges[a]!;
    final prevEnd = k == 0 ? -1 : anchors[k - 1];
    final nextAnchor = k + 1 < anchors.length ? anchors[k + 1] : lines.length;
    final header = <String>[];
    final desc = <String>[];

    // text on the date line itself (besides the range)
    final inline = lines[a]
        .replaceRange(r.match.start, r.match.end, ' ')
        .replaceAll(RegExp(r'[()\[\]|]'), ' ')
        .replaceAll(RegExp(r'\s[–—-]\s*$'), '')
        .trim();
    final inlineUseful = RegExp(r'\p{L}{3,}', unicode: true).hasMatch(inline);

    if (dateFirst) {
      var i = a + 1;
      if (inlineUseful) header.add(inline);
      while (i < nextAnchor && header.length < 2 && _isHeaderish(lines[i])) {
        header.add(lines[i]);
        i++;
      }
      for (; i < nextAnchor; i++) {
        desc.add(_unbullet(lines[i]));
      }
    } else {
      if (inlineUseful) header.add(inline);
      // header lines are the short non-bullet lines right before the anchor (after the previous entry's description)
      var j = a - 1;
      final before = <String>[];
      while (j > prevEnd && before.length < 2 && _isHeaderish(lines[j])) {
        before.insert(0, lines[j]);
        j--;
      }
      header.insertAll(0, before);
      // the description is everything after the anchor up to the next entry's header
      var end = nextAnchor;
      if (k + 1 < anchors.length) {
        var h = nextAnchor - 1;
        var taken = 0;
        while (h > a && taken < 2 && _isHeaderish(lines[h])) {
          h--;
          taken++;
        }
        end = h + 1;
      }
      for (var i = a + 1; i < end; i++) {
        desc.add(_unbullet(lines[i]));
      }
    }
    final (title, company) = _splitTitleCompany(header);
    if (title.isEmpty && company.isEmpty) continue;
    final description = desc.where((e) => e.isNotEmpty).join('\n');
    out.add(
      SuggestedExperience(
        title: title,
        company: company,
        start: r.start,
        end: r.end,
        description: description.isEmpty
            ? null
            : (description.length > 4000
                  ? description.substring(0, 4000)
                  : description),
      ),
    );
  }
  return out;
}

final _degreeFieldRe = RegExp(
  r'^(.*?(?:bacharelado|licenciatura|tecn[oó]logo|t[eé]cnico|gradua[cç][aã]o|mestrado|doutorado|p[oó]s[- ]gradua[cç][aã]o|especializa[cç][aã]o|mba|grado|m[aá]ster|master|doctorado|bachelor|b\.?sc\.?|m\.?sc\.?|ph\.?d\.?|diploma|degree|associate)[a-zç]*\.?)\s+(?:em|in|of|en|de|do|da)\s+(.+)$',
  caseSensitive: false,
);

List<SuggestedEducation> _education(List<String> lines) {
  final anchors = <int>[];
  final ranges = <int, _Range>{};
  for (var i = 0; i < lines.length; i++) {
    final r = _rangeIn(lines[i]);
    if (r != null && !_isBullet(lines[i])) {
      anchors.add(i);
      ranges[i] = r;
    }
  }
  final out = <SuggestedEducation>[];

  SuggestedEducation build(List<String> header, _Range? r) {
    final joined = header.where((e) => e.trim().isNotEmpty).toList();
    String institution = '';
    String? degree;
    if (joined.length >= 2) {
      final aSchool = _schoolHint.hasMatch(joined[0]);
      final bSchool = _schoolHint.hasMatch(joined[1]);
      if (aSchool && !bSchool) {
        institution = joined[0];
        degree = joined[1];
      } else {
        degree = joined[0];
        institution = joined[1];
      }
    } else if (joined.length == 1) {
      final one = joined.first;
      final two = _split2(one);
      if (two != null) {
        final (left, right) = two;
        if (_schoolHint.hasMatch(left) && !_schoolHint.hasMatch(right)) {
          institution = left;
          degree = right;
        } else {
          degree = left;
          institution = right;
        }
      } else if (_schoolHint.hasMatch(one)) {
        // "B.Sc. in Computer Science, University of California, Berkeley": the degree comes before the school's name
        final segs = one.split(RegExp(r'\s*,\s*'));
        final k = segs.indexWhere(_schoolHint.hasMatch);
        if (k > 0) {
          degree = segs.sublist(0, k).join(', ');
          institution = segs.sublist(k).join(', ');
        } else {
          institution = one;
        }
      } else {
        degree = one;
      }
    }
    institution = institution.replaceAll(RegExp(r',.*$'), '').trim().isEmpty
        ? institution.trim()
        : institution.replaceAll(RegExp(r'\s*\(.*\)$'), '').trim();
    String? field;
    if (degree != null) {
      final m = _degreeFieldRe.firstMatch(degree);
      if (m != null) {
        degree = m.group(1)!.trim();
        field = m.group(2)!.trim();
      }
    }
    return SuggestedEducation(
      institution: institution,
      degree: degree,
      field: field,
      start: r?.start,
      end: r?.end,
    );
  }

  if (anchors.isNotEmpty) {
    for (var k = 0; k < anchors.length; k++) {
      final a = anchors[k];
      final r = ranges[a]!;
      final prev = k == 0 ? -1 : anchors[k - 1];
      final inline = lines[a]
          .replaceRange(r.match.start, r.match.end, ' ')
          .replaceAll(RegExp(r'[()\[\]|]'), ' ')
          .trim();
      final header = <String>[];
      var j = a - 1;
      while (j > prev && header.length < 2 && _isHeaderish(lines[j])) {
        header.insert(0, lines[j]);
        j--;
      }
      if (RegExp(r'\p{L}{3,}', unicode: true).hasMatch(inline)) {
        header.add(inline.replaceAll(RegExp(r'\s+'), ' '));
      }
      if (header.isEmpty) {
        // date-first layout
        var i = a + 1;
        final next = k + 1 < anchors.length ? anchors[k + 1] : lines.length;
        while (i < next && header.length < 2 && _isHeaderish(lines[i])) {
          header.add(lines[i]);
          i++;
        }
      }
      final e = build(header, r);
      if (e.institution.isNotEmpty || (e.degree ?? '').isNotEmpty) out.add(e);
    }
    return out;
  }

  // no dates: one entry per line that names a school (with the degree on the same or the previous line)
  for (var i = 0; i < lines.length; i++) {
    if (_schoolHint.hasMatch(lines[i])) {
      final header = [
        if (i > 0 && !_schoolHint.hasMatch(lines[i - 1])) lines[i - 1],
        lines[i],
      ];
      final e = build(
        header.length == 2 ? [header[0], header[1]] : header,
        null,
      );
      if (e.institution.isNotEmpty) out.add(e);
    }
  }
  return out;
}
