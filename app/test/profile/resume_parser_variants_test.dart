// Résumé variants of OrbiJob 9.0: professions other than technology, credentials after the name, "City - ST", abbreviations such as
// "S.A. de C.V.", month/year written "Fev/2019", a title-first layout whose previous entry ends in an acronym, and German headings.
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/profile/domain/resume_parser.dart';

const cvs = <String, String>{
  'nurse-en': '''Priya Nair, RN
Registered Nurse – Intensive Care
priya.nair@example.com | +44 7700 900123 | Manchester, United Kingdom

PROFESSIONAL SUMMARY
ICU nurse with 9 years of experience in adult critical care.

WORK EXPERIENCE
Senior Staff Nurse, Royal Infirmary Hospital
June 2018 – Present
- Lead a team of 6 nurses on a 12-bed unit
- Mentor student nurses

Staff Nurse, St Mary's Hospital
Sep 2014 – May 2018
- Adult ICU care

EDUCATION
BSc Nursing, University of Manchester, 2010 – 2014

CERTIFICATIONS
NMC Registration (UK), BLS, ACLS

LANGUAGES
English (Native), Malayalam (Native), Hindi (Fluent)
''',
  'electrician-es': '''CARLOS RAMÍREZ PÉREZ
Electricista industrial
Correo: carlos.ramirez@example.com  Tel: +52 55 1234 5678
Ciudad de México, México

PERFIL
Electricista con 12 años de experiencia en instalaciones industriales y mantenimiento.

EXPERIENCIA LABORAL
Electricista de mantenimiento — Grupo Industrial Norte S.A. de C.V.
03/2015 - Actualidad
Mantenimiento de tableros, motores y PLC.

Ayudante de electricista | Instalaciones Eléctricas del Centro
01/2010 - 02/2015

FORMACIÓN
Técnico en Electricidad Industrial - CONALEP, 2007 - 2010

HABILIDADES
Instalaciones eléctricas, Lectura de planos, PLC, Soldadura básica

IDIOMAS
Español: nativo; Inglés: básico
''',
  'teacher-pt': '''Ana Beatriz Lima
Professora de Matemática
ana.lima@example.com • (31) 99876-5432 • Belo Horizonte - MG

Resumo
Professora do ensino fundamental e médio há 7 anos.

Experiência
Professora de Matemática — Colégio Santa Clara
Fev/2019 – Atual
Aulas para o ensino médio, elaboração de provas.

Professora substituta, Escola Estadual João Pinheiro
2016 – 2018

Formação Acadêmica
Licenciatura em Matemática — Universidade Federal de Minas Gerais (2012 – 2016)

Idiomas
Português (nativo), Inglês (intermediário)
''',
  'driver-de': '''Lebenslauf
Jürgen Weber
Berufskraftfahrer CE
juergen.weber@example.de, Tel. 0151 2345678
Hamburg, Deutschland

Berufserfahrung
Fernfahrer, Nordtrans GmbH
01/2016 – heute
Fernverkehr in Deutschland und Europa

Kraftfahrer, Spedition Müller KG
2010 – 2015

Ausbildung
Berufskraftfahrer, IHK Hamburg, 2007 – 2010

Sprachen
Deutsch (Muttersprache), Englisch (Grundkenntnisse)
''',
  'welder-pt': '''JOSÉ CARLOS DA SILVA
Soldador MIG/TIG - Caldeiraria
Tel: (11) 98888-7777 | jose.silva@example.com
Santo André/SP

OBJETIVO
Atuar como soldador em empresa de grande porte.

HISTÓRICO PROFISSIONAL
Soldador Especializado - Metalúrgica Forte Ltda
10/2017 a 08/2026
Soldagem MIG, TIG e eletrodo revestido em aço carbono e inox.

Soldador - Caldeiraria ABC
2012 a 2017

ESCOLARIDADE
Ensino médio completo
Curso de Soldador - SENAI, 2011

CURSOS
NR-10, NR-35, Inspetor de soldagem N1
''',
};

String _p(DateTime? d) => d == null ? 'now' : '${d.year}-${d.month}';

void main() {
  ResumeSuggestion parse(String k) => parseResumeText(cvs[k]!);

  test('nurse: "Name, RN" is the name (not a city), the headline, the UK and the entries are read', () {
    final s = parse('nurse-en');
    expect(s.name, 'Priya Nair');
    expect(s.headline, 'Registered Nurse – Intensive Care');
    expect((s.city, s.country), ('Manchester', 'GB'));
    expect(
      s.experiences.map((e) => (e.title, e.company, _p(e.start), _p(e.end))),
      [
        ('Senior Staff Nurse', 'Royal Infirmary Hospital', '2018-6', 'now'),
        ('Staff Nurse', "St Mary's Hospital", '2014-9', '2018-5'),
      ],
    );
  });

  test('electrician: a company ending in "S.A. de C.V." stays a header, and the second entry keeps its own dates', () {
    final s = parse('electrician-es');
    expect(
      s.experiences.map((e) => (e.title, e.company, _p(e.start), _p(e.end))),
      [
        (
          'Electricista de mantenimiento',
          'Grupo Industrial Norte S.A. de C.V.',
          '2015-3',
          'now',
        ),
        (
          'Ayudante de electricista',
          'Instalaciones Eléctricas del Centro',
          '2010-1',
          '2015-2',
        ),
      ],
    );
    expect(s.experiences.first.description, contains('PLC'));
    expect((s.city, s.country), ('Ciudad de México', 'MX'));
  });

  test('teacher: "Fev/2019 – Atual" is a date (not part of the company) and "Belo Horizonte - MG" is the city', () {
    final s = parse('teacher-pt');
    expect(s.city, 'Belo Horizonte');
    expect(
      s.experiences.map((e) => (e.title, e.company, _p(e.start), _p(e.end))),
      [
        ('Professora de Matemática', 'Colégio Santa Clara', '2019-2', 'now'),
        (
          'Professora substituta',
          'Escola Estadual João Pinheiro',
          '2016-1',
          '2018-1',
        ),
      ],
    );
  });

  test('truck driver (German): headings, "heute", "Muttersprache", one-line "Title, Company" headers', () {
    final s = parse('driver-de');
    expect((s.name, s.city, s.country), ('Jürgen Weber', 'Hamburg', 'DE'));
    expect(s.languages.map((l) => (l.code, l.level)), [
      ('de', 'Muttersprache'),
      ('en', 'Grundkenntnisse'),
    ]);
    expect(
      s.experiences.map((e) => (e.title, e.company, _p(e.start), _p(e.end))),
      [
        ('Fernfahrer', 'Nordtrans GmbH', '2016-1', 'now'),
        ('Kraftfahrer', 'Spedition Müller KG', '2010-1', '2015-1'),
      ],
    );
    expect(s.experiences.first.description, contains('Fernverkehr'));
    final e = s.education.single;
    expect((e.degree, e.institution), ('Berufskraftfahrer', 'IHK Hamburg'));
  });

  test('welder: "Santo André/SP" is the city and "a" separates the dates', () {
    final s = parse('welder-pt');
    expect(s.city, 'Santo André');
    expect(
      s.experiences.map((e) => (e.title, e.company, _p(e.start), _p(e.end))),
      [
        (
          'Soldador Especializado',
          'Metalúrgica Forte Ltda',
          '2017-10',
          '2026-8',
        ),
        ('Soldador', 'Caldeiraria ABC', '2012-1', '2017-1'),
      ],
    );
  });
}
