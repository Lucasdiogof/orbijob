/// Lower case, accents removed, anything that is not a letter or digit turned into a single space. Used to compare words, never to show them.
const _accents = {
  'a': 'àáâãäåāăą',
  'c': 'çćč',
  'd': 'ď',
  'e': 'èéêëēėęě',
  'i': 'ìíîïīį',
  'l': 'ł',
  'n': 'ñńň',
  'o': 'òóôõöøōő',
  'r': 'ř',
  's': 'śšş',
  't': 'ť',
  'u': 'ùúûüūůűų',
  'y': 'ýÿ',
  'z': 'źżž',
};
final Map<String, String> _plain = {
  for (final e in _accents.entries)
    for (final ch in e.value.split('')) ch: e.key,
  'ß': 'ss',
};

String normalizeForMatch(String input) {
  final b = StringBuffer();
  for (final r in input.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final plain = _plain[ch];
    if (plain != null) {
      b.write(plain);
    } else if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch)) {
      b.write(ch);
    } else {
      b.write(' ');
    }
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
