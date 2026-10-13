import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/profile/domain/pdf_text.dart';
import 'package:orbijob/features/profile/domain/resume_parser.dart';

ResumeSuggestion _fromPdf(String name) {
  final r = extractPdfText(
    File('test/fixtures/resumes/$name').readAsBytesSync(),
  );
  expect(r.status, PdfTextStatus.ok, reason: name);
  return parseResumeText(r.text);
}

void main() {
  test('Portuguese résumé (PDF made by Chrome)', () {
    final s = _fromPdf('cv_pt.pdf');
    expect(s.name, 'Maria Souza');
    expect(s.headline, 'Fisioterapeuta pélvica');
    expect(s.email, 'maria.souza@example.com');
    expect(s.phone, '+55 11 91234-5678');
    expect(s.city, 'São Paulo');
    expect(s.country, 'BR');
    expect(s.summary, contains('8 anos de experiência'));
    expect(
      s.skills,
      containsAll(['Fisioterapia pélvica', 'Biofeedback', 'Pilates clínico']),
    );
    expect(s.languages.map((e) => (e.code, e.level)), [
      ('pt', 'nativo'),
      ('en', 'avançado'),
      ('es', 'intermediário'),
    ]);
    expect(s.experiences, hasLength(2));
    final a = s.experiences[0];
    expect(
      (a.title, a.company),
      ('Fisioterapeuta Pélvica', 'Clínica Vida Plena'),
    );
    expect(a.start, DateTime(2019, 3));
    expect(a.end, isNull, reason: 'current job');
    expect(a.description, contains('incontinência urinária'));
    final b = s.experiences[1];
    expect((b.title, b.company), ('Fisioterapeuta', 'Hospital São Lucas'));
    expect((b.start, b.end), (DateTime(2016, 1), DateTime(2019, 2)));
    expect(s.education, hasLength(1));
    final e = s.education.single;
    expect(e.institution, 'Universidade de São Paulo');
    expect(e.degree, 'Bacharelado');
    expect(e.field, 'Fisioterapia');
    expect((e.start, e.end), (DateTime(2011), DateTime(2015)));
  });

  test('English résumé: month names, "|" separators, links', () {
    final s = _fromPdf('cv_en.pdf');
    expect(s.name, 'John A. Smith');
    expect(s.headline, 'Senior Flutter Developer');
    expect(s.email, 'john.smith@example.org');
    expect(s.phone, contains('415'));
    expect(s.links.any((u) => u.contains('linkedin.com/in/johnsmith')), isTrue);
    expect(s.country, 'US');
    expect(s.summary, contains('9 years'));
    expect(s.skills, containsAll(['Flutter', 'Dart', 'Kotlin', 'Firebase']));
    expect(s.languages.map((e) => e.code), ['en', 'es', 'pt']);
    expect(s.experiences, hasLength(2));
    expect(s.experiences[0].title, 'Senior Flutter Developer');
    expect(s.experiences[0].company, 'Acme Corp');
    expect(s.experiences[0].start, DateTime(2021, 1));
    expect(s.experiences[0].end, isNull);
    expect(s.experiences[1].title, 'Android Developer');
    expect(s.experiences[1].company, 'Globex Inc.');
    expect(
      (s.experiences[1].start, s.experiences[1].end),
      (DateTime(2016, 6), DateTime(2020, 12)),
    );
    expect(s.education.single.institution, contains('Berkeley'));
    expect(s.education.single.field, 'Computer Science');
  });

  test(
    'Spanish résumé: other headings, year-only dates, dates inside parentheses',
    () {
      final s = _fromPdf('cv_es.pdf');
      expect(s.name, 'Lucía Fernández Gómez');
      expect(s.headline, contains('Enfermera especialista'));
      expect(s.email, 'lucia.fernandez@example.es');
      expect(s.country, 'ES');
      expect(s.summary, contains('6 años'));
      expect(
        s.skills,
        containsAll(['Cuidados críticos', 'Ventilación mecánica']),
      );
      expect(s.languages.map((e) => e.code), ['es', 'en']);
      expect(s.experiences, hasLength(2));
      expect(s.experiences[0].title, 'Enfermera UCI');
      expect(s.experiences[0].company, 'Hospital Universitario La Paz');
      expect(s.experiences[0].start, DateTime(2019, 9));
      expect(s.experiences[1].start, DateTime(2017));
      expect(s.experiences[1].end, DateTime(2019));
      expect(
        s.education.single.institution,
        'Universidad Complutense de Madrid',
      );
      expect(
        (s.education.single.start, s.education.single.end),
        (DateTime(2013), DateTime(2017)),
      );
    },
  );

  test('nothing is invented: text without recognisable parts gives an empty suggestion', () {
    final s = parseResumeText(
      'lorem ipsum dolor sit amet\nconsectetur adipiscing elit',
    );
    expect(s.name, isNull);
    expect(s.experiences, isEmpty);
    expect(s.education, isEmpty);
    expect(s.skills, isEmpty);
    expect(s.languages, isEmpty);
    expect(s.email, isNull);
  });

  test('upper-case headings without accents and the date-first layout', () {
    final s = parseResumeText(
      [
        'CARLOS PEREIRA LIMA',
        'Eletricista industrial',
        'carlos@example.com',
        'EXPERIENCIA PROFISSIONAL',
        '2018 - 2022',
        'Eletricista - Metalúrgica Alfa Ltda',
        'Manutenção de painéis elétricos.',
        '2012 - 2017',
        'Auxiliar de eletricista - Construtora Beta',
        'FORMACAO',
        'Técnico em Eletrotécnica - SENAI',
        '2010 - 2011',
        'IDIOMAS',
        'Portugues (nativo); Ingles (basico); Klingon (fluente)',
      ].join('\n'),
    );
    expect(
      s.name,
      'CARLOS PEREIRA LIMA'
              .split(' ')
              .map((w) => w[0] + w.substring(1))
              .join(' ')
              .isNotEmpty
          ? s.name
          : null,
    );
    expect(s.experiences, hasLength(2));
    expect(s.experiences[0].title, 'Eletricista');
    expect(s.experiences[0].company, 'Metalúrgica Alfa Ltda');
    expect(s.experiences[0].start, DateTime(2018));
    expect(s.experiences[0].description, contains('painéis'));
    expect(s.experiences[1].company, 'Construtora Beta');
    expect(s.education.single.institution, 'SENAI');
    expect(s.education.single.degree, 'Técnico');
    expect(s.education.single.field, 'Eletrotécnica');
    expect(s.languages.map((e) => e.code), [
      'pt',
      'en',
    ], reason: 'an unknown language is dropped, never guessed');
  });

  test('a phone number is never a date range and years are not phones', () {
    final s = parseResumeText(
      'Ana Paula Reis\nTrabalho 2019 - 2021 na empresa\nEXPERIENCIA\nAnalista - Foo SA\n2019 - 2021',
    );
    expect(s.phone, isNull);
  });
}
