/// Parts of a listing that must never be translated: addresses, e-mails, salary figures, reference codes, gender markers such as
/// "(m/w/d)", acronyms (professional registers like CREFITO or AHPRA, certifications, language levels like B2) and the company's
/// own name. They are swapped for opaque markers before the engine sees the text and put back afterwards. A line is only used when
/// EVERY marker comes back exactly once; otherwise the caller keeps the original line (a wrong number or a changed registration
/// is worse than an untranslated sentence).
library;

class ProtectedLine {
  const ProtectedLine(this.text, this.originals);

  /// The line with markers (`⟦0⟧`, `⟦1⟧`, …) where protected parts were.
  final String text;

  /// The protected parts, by marker number.
  final List<String> originals;

  bool get hasProtected => originals.isNotEmpty;
}

final _markerRe = RegExp(r'⟦\s*(\d+)\s*⟧');

final _url = r'(?:https?:\/\/|www\.)[^\s<>"”)]+';
final _email = r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}';
final _gender =
    r'\((?:[mwfdxhiu]\s*[\/|]\s*){1,3}[mwfdxhiu]\)|\b[mwfd]\/[mwfdx](?:\/[mwfdx])?\b';
final _currency =
    r'(?:EUR|USD|GBP|NZD|AUD|CAD|CHF|SEK|NOK|DKK|TWD|JPY|BRL|NT\$|R\$|US\$|NZ\$|A\$|C\$|[€$£¥₩₫₹])';
final _money =
    '$_currency\\s?\\d[\\d.,\\u00a0\\u202f ]*\\d(?:\\s?(?:k|K|M|mil|tusen|Mio\\.?|T))?(?:\\s?[-–]\\s?\\d[\\d.,]*\\d)?'
    '|\\d[\\d.,\\u00a0\\u202f]*\\d\\s?$_currency(?![A-Za-z])';
final _ref =
    r'(?:Ref(?:erence|erenz|erencia)?|Job\s?ID|ID|Req(?:uisition)?|Kennziffer|Chiffre|Referenznummer)\.?[\s:#\-]*[A-Z0-9][A-Z0-9/_\-]{2,}';
final _acronym =
    r'\b[A-ZÄÖÜÅÆØ][A-ZÄÖÜÅÆØ0-9]{1,9}(?:[/&\-][A-ZÄÖÜÅÆØ0-9]{1,9})*\b';
final _level =
    r'\b(?:[ABC][12]|N[1-5]|HSK\s?\d|TOEIC\s?\d+|IELTS\s?\d(?:\.\d)?)\b';
final _licence =
    r'(?:Klasse|Führerschein|Fuehrerschein|Class|Permis|Körkort|Licence|License|Carta|Carnet)\s+[A-Z]{1,3}\d?\b';

/// Splits [line] into protected parts and replaces them by markers. [keep] are extra literal strings (the company name).
ProtectedLine protectLine(String line, {Iterable<String> keep = const []}) {
  final parts = <String>[
    _url,
    _email,
    _ref,
    _gender,
    _money,
    _licence,
    _level,
    for (final k in keep)
      if (k.trim().length >= 3) RegExp.escape(k.trim()),
  ];
  // an all-capitals line is a heading ("WIR BIETEN"), not a list of acronyms: translate it as text
  final letters = RegExp(r'\p{L}', unicode: true).allMatches(line).length;
  final upper = RegExp(r'\p{Lu}', unicode: true).allMatches(line).length;
  final isHeading = letters >= 6 && upper / letters > 0.8;
  if (!isHeading) parts.add(_acronym);
  final re = RegExp(parts.join('|'), unicode: true);

  final originals = <String>[];
  final out = StringBuffer();
  var last = 0;
  for (final m in re.allMatches(line)) {
    if (m.start < last) continue;
    final s = m.group(0)!;
    // a lone capital letter or a two-letter word at the start of a sentence is not an acronym worth protecting
    if (s.length < 2) continue;
    out.write(line.substring(last, m.start));
    out.write('⟦${originals.length}⟧');
    originals.add(s);
    last = m.end;
  }
  out.write(line.substring(last));
  return ProtectedLine(out.toString(), originals);
}

/// Puts the protected parts back. Returns null when the engine lost, duplicated or invented a marker (the line is then not trusted).
String? restoreLine(String translated, ProtectedLine p) {
  if (p.originals.isEmpty) return translated;
  final seen = <int>{};
  var ok = true;
  final result = translated.replaceAllMapped(_markerRe, (m) {
    final i = int.parse(m.group(1)!);
    if (i < 0 || i >= p.originals.length || !seen.add(i)) {
      ok = false;
      return m.group(0)!;
    }
    return p.originals[i];
  });
  if (!ok || seen.length != p.originals.length) return null;
  return result;
}

/// A list bullet or numbering at the start of a line, kept verbatim.
final _bulletRe = RegExp(r'^\s*(?:[•·▪■◦●\-–—*►➢✓]|\d{1,2}[.)])\s+');

({String prefix, String body}) splitBullet(String line) {
  final m = _bulletRe.firstMatch(line);
  if (m == null) return (prefix: '', body: line);
  return (prefix: m.group(0)!, body: line.substring(m.end));
}

/// Breaks a long line at sentence ends into pieces of at most [max] characters (never inside a marker).
List<String> chunkLine(String line, {int max = 500}) {
  if (line.length <= max) return [line];
  final sentences = line.split(RegExp(r'(?<=[.!?。！？;；])\s+'));
  final chunks = <String>[];
  var cur = StringBuffer();
  for (final s in sentences) {
    if (cur.length + s.length + 1 > max && cur.isNotEmpty) {
      chunks.add(cur.toString());
      cur = StringBuffer();
    }
    if (cur.isNotEmpty) cur.write(' ');
    cur.write(s);
  }
  if (cur.isNotEmpty) chunks.add(cur.toString());
  // a single "sentence" longer than max (no punctuation): split at spaces
  return [
    for (final c in chunks)
      if (c.length <= max * 2) c else ..._splitAtSpaces(c, max),
  ];
}

List<String> _splitAtSpaces(String s, int max) {
  final out = <String>[];
  var cur = StringBuffer();
  for (final w in s.split(' ')) {
    if (cur.length + w.length + 1 > max && cur.isNotEmpty) {
      out.add(cur.toString());
      cur = StringBuffer();
    }
    if (cur.isNotEmpty) cur.write(' ');
    cur.write(w);
  }
  if (cur.isNotEmpty) out.add(cur.toString());
  return out;
}
