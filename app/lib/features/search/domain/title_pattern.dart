/// One case-insensitive POSIX regular expression that matches a title containing ANY of [keywords] as a plain substring.
///
/// It replaces a PostgREST `or=(title.ilike.*a*,title.ilike.*b*,...)` list of up to ~100 patterns. The server turned that list into one
/// trigram-index scan per pattern, so a count cost about 40 ms per keyword and the largest areas passed the 3-second statement limit of the
/// public role (HTTP 500 `57014`). A single `title ~* 'a|b|...'` answers the same question in one pass: measured on the real catalogue
/// (2026-10-17), the counts of all 16 areas that the old filter could answer were identical and 3 to 4 times faster, and the two it
/// could not (technology and health) now answer in about 1 s.
///
/// Every regex metacharacter in a keyword is escaped, so a keyword can only ever match literally. Send it with `imatch` (`~*`):
/// `query.filter('title', 'imatch', titleAlternation(keywords))`.
String titleAlternation(Iterable<String> keywords) =>
    [for (final k in keywords) _escape(k)].join('|');

String _escape(String keyword) {
  const meta = r'.^$*+?()[]{}|\';
  final out = StringBuffer();
  for (final rune in keyword.runes) {
    final c = String.fromCharCode(rune);
    if (meta.contains(c)) out.write(r'\');
    out.write(c);
  }
  return out.toString();
}
