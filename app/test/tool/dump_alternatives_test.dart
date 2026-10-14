import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/search_alternatives.dart';
import 'package:orbijob/features/search/domain/search_synonyms.dart';

/// Writes what the app would search for every benchmark query (scripts/search-benchmark.mjs reads it):
///   DUMP_ALTS=1 flutter test test/tool/dump_alternatives_test.dart
/// `before` is the OrbiJob 4.0 behaviour (flat fragments anywhere in the title), `after` the 5.0 one (alternatives with required parts).
/// The 4.0 expansion: the groups that existed then (electrician, welder and cook were added in 5.0), fragments anywhere in the title.
List<String> _legacy(String t) {
  const added = {'electrician', 'welder', 'cook'};
  final out = <String>{};
  for (final g in synonymGroups) {
    if (g.any(added.contains)) continue;
    if (g.any(t.contains)) out.addAll(g.where((w) => !t.contains(w)));
  }
  return out.toList();
}

void main() {
  test('dump the alternatives of the benchmark queries', () {
    if (Platform.environment['DUMP_ALTS'] != '1') return;
    final queries = (jsonDecode(
      File(
        Platform.environment['BENCH_QUERIES'] ??
            '../scripts/search-benchmark.queries.json',
      ).readAsStringSync(),
    ) as List).cast<String>();
    final out = {
      for (final q in queries)
        q: {
          'before': [
            for (final s in _legacy(q.toLowerCase())) [s],
          ],
          'after': titleAlternatives(q),
        },
    };
    File(
      Platform.environment['BENCH_ALTS'] ??
          '../scripts/search-benchmark.alternatives.json',
    ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(out)}\n');
  });
}
