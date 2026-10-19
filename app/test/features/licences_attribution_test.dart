import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/main.dart';

/// The licence page names every open-data job source with the licence it really uses (13.0: the five French and Spanish public sources).
void main() {
  test('the job-listings licence entry names each open-data source with its own licence', () async {
    registerJobSourceAttributions();
    final entries = await LicenseRegistry.licenses.toList();
    final text = entries
        .where((e) => e.packages.contains('Job listings (open data)'))
        .expand((e) => e.paragraphs.map((p) => p.text))
        .join(' ');

    // single line breaks are joined into one paragraph: cut the text of a source from its name to the name of the next one
    const starts = [
      'Úřad práce',
      'Choisir le Service Public (',
      'SEF, Servicio de Empleo',
      'Feina Activa,',
      'ECYL,',
      'Lanbide,',
      'Listings are shown',
    ];
    String part(String source) {
      final from = text.indexOf(source);
      if (from < 0) return '';
      var end = text.length;
      for (final s in starts) {
        final i = text.indexOf(s, from + source.length);
        if (i > from && i < end) end = i;
      }
      return text.substring(from, end);
    }

    expect(
      part('Choisir le Service Public ('),
      contains('Licence Ouverte v2.0'),
    );
    expect(
      part('Feina Activa,'),
      contains("Llicència oberta d'ús d'informació - Catalunya"),
    );
    expect(part('Feina Activa,'), isNot(contains('CC BY')));
    expect(part('SEF, Servicio de Empleo'), contains('avisolegal'));
    expect(part('SEF, Servicio de Empleo'), isNot(contains('CC BY')));
    expect(part('ECYL,'), contains('CC BY 4.0'));
    expect(part('Lanbide,'), contains('CC BY 4.0'));
    expect(part('Úřad práce'), contains('podminky-uziti'));
    for (final s in starts.take(6)) {
      expect(part(s), contains('https://'), reason: s);
    }
  });
}
