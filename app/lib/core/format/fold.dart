/// Lower-case without diacritics, for comparing what a person types with what a listing says ("sênior" / "Senior", "pélvica" / "pelvica").
///
/// The table is the same as `ops.fold` in the database (supabase/migrations/20261027000000_accent_insensitive_search.sql): the catalogue's
/// folded columns and the folded search term must agree character by character, so any change here is a change there.
String foldAccents(String s) {
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
