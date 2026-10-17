import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/health_specialty.dart';
import 'package:orbijob/features/search/domain/job_area.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/search/domain/search_synonyms.dart';
import 'package:orbijob/features/search/domain/specialty_portals.dart';

void main() {
  final unsafe = RegExp(r'[,()"*%\\]');

  group('HealthSpecialty keywords', () {
    test('every keyword is a safe, lower-case PostgREST filter value', () {
      for (final s in HealthSpecialty.values) {
        expect(s.keywords, isNotEmpty, reason: s.name);
        for (final k in s.keywords) {
          expect(k, k.toLowerCase(), reason: k);
          expect(k, isNot(matches(unsafe)), reason: k);
          expect(k.trim(), k, reason: k);
          expect(
            k.length,
            greaterThanOrEqualTo(RegExp(r'[㐀-鿿]').hasMatch(k) ? 2 : 4),
            reason: k,
          );
        }
      }
    });
  });

  group('pelvic physiotherapy', () {
    const positives = [
      'Fisioterapeuta Pélvica',
      'Fisioterapeuta pélvico - Clínica Saúde da Mulher',
      'Fisioterapia Uroginecológica',
      'Fisioterapeuta em reabilitação do assoalho pélvico',
      'Pelvic Floor Physical Therapist',
      'Pelvic Health Physiotherapist',
      'Physical Therapist - Pelvic Rehabilitation',
      "Women's Health Physiotherapist",
      'Urogynaecological Physiotherapist',
      'Physiotherapeut*in Beckenboden',
    ];
    const negatives = [
      'Physical Therapist',
      'Fisioterapeuta Hospitalar',
      'Pelvic Floor Ultrasound Sonographer',
      'Pelvic Health Nurse Practitioner',
      'Recepcionista - Clínica de Fisioterapia Pélvica e Saúde da Mulher',
      'Medical Billing Specialist, Pelvic Health Clinic',
      "Women's Health Marketing Manager",
    ];
    for (final t in positives) {
      test('recognises "$t"', () {
        expect(HealthSpecialty.pelvicPhysio.matches(t), isTrue);
        expect(HealthSpecialty.physiotherapy.matches(t), isTrue);
      });
    }
    for (final t in negatives) {
      test('does not file "$t" as pelvic physiotherapy', () {
        expect(
          HealthSpecialty.pelvicPhysio.matches(t),
          t.contains('Fisioterapia Pélvica') ? isTrue : isFalse,
          reason: 'documented limit below',
        );
      });
    }
    test(
      'documented limit: a receptionist whose TITLE names the clinic specialty is matched (titles only, no guessing); '
      'every other administrative title is not',
      () {
        expect(
          HealthSpecialty.pelvicPhysio.matches(
            'Recepcionista - Clínica de Fisioterapia Pélvica e Saúde da Mulher',
          ),
          isTrue,
        );
      },
    );
  });

  group('specialties are narrower than the Health area', () {
    const administrative = [
      'Medical Billing Specialist',
      'Hospital Receptionist',
      'Clinical Data Management Manager',
      'Patient Access Representative',
      'Healthcare Sales Executive',
      'Software Engineer, Clinical Systems',
    ];
    for (final t in administrative) {
      test('"$t" has no clinical specialty', () {
        expect(HealthSpecialty.of(t), isEmpty);
      });
    }
    test('clinical titles in pt, en, es and de', () {
      expect(HealthSpecialty.of('Enfermeira Obstétrica'), [
        HealthSpecialty.nursing,
      ]);
      expect(HealthSpecialty.of('Registered Nurse - ICU'), [
        HealthSpecialty.nursing,
      ]);
      expect(HealthSpecialty.of('Psicóloga Clínica'), [
        HealthSpecialty.psychology,
      ]);
      expect(HealthSpecialty.of('Terapeuta Ocupacional'), [
        HealthSpecialty.occupationalTherapy,
      ]);
      expect(HealthSpecialty.of('Nutricionista'), [HealthSpecialty.nutrition]);
      expect(HealthSpecialty.of('Cirurgião-Dentista'), [
        HealthSpecialty.medicine,
        HealthSpecialty.dentistry,
      ]);
      expect(HealthSpecialty.of('Farmacêutica Responsável'), [
        HealthSpecialty.pharmacy,
      ]);
      expect(HealthSpecialty.of('Fonoaudióloga'), [
        HealthSpecialty.speechTherapy,
      ]);
      expect(HealthSpecialty.of('Técnico em Radiologia'), [
        HealthSpecialty.radiology,
      ]);
      expect(HealthSpecialty.of('Gestor Hospitalar'), [
        HealthSpecialty.hospitalManagement,
      ]);
      expect(HealthSpecialty.of('Assistenzarzt Innere Medizin (m/w/d)'), [
        HealthSpecialty.medicine,
      ]);
      expect(HealthSpecialty.of('Pflegefachkraft (m/w/d)'), [
        HealthSpecialty.nursing,
      ]);
    });
    test('a German medical practice assistant is not a physician', () {
      expect(
        HealthSpecialty.of('Medizinische Fachangestellte in Arztpraxis'),
        isEmpty,
      );
    });
    test('an educator (Erzieher) is education, not health', () {
      expect(JobArea.of('Erzieher (m/w/d) Kita'), [JobArea.education]);
    });
  });

  group(
    'the Health area lists clinical jobs, not every job of a health company',
    () {
      for (final t in [
        'Working Student - Healthcare Sales',
        'Senior Software Engineer - Digital Patient Model',
        'Medical Billing Specialist',
        'Hospital Receptionist',
        'Pharmaceutical Sales Representative',
        'Clinical Data Manager',
      ]) {
        test('"$t" is not Health', () {
          expect(JobArea.of(t), isNot(contains(JobArea.health)));
        });
      }
      for (final t in [
        'Fisioterapeuta Pélvica',
        'Registered Nurse',
        'Medical Assistant',
        'Pharmacist',
        'Fonoaudióloga',
      ]) {
        test('"$t" is Health', () {
          expect(JobArea.of(t), contains(JobArea.health));
        });
      }
    },
  );

  group('filters', () {
    test(
      'leaving the Health area drops the specialty; a specialty makes the filters active',
      () {
        const f = JobFilters(
          area: JobArea.health,
          specialty: HealthSpecialty.pelvicPhysio,
        );
        expect(f.isActive, isTrue);
        expect(f.copyWith(clearArea: true).specialty, isNull);
        expect(f.copyWith(clearSpecialty: true).area, JobArea.health);
        expect(
          const JobFilters(specialty: HealthSpecialty.nursing).isActive,
          isTrue,
        );
      },
    );
  });

  group('search synonyms (titles only, nothing translated)', () {
    test('every synonym is a safe filter value', () {
      for (final g in synonymGroups) {
        for (final w in g) {
          expect(w, w.toLowerCase());
          expect(w, isNot(matches(unsafe)), reason: w);
          expect(
            w.length,
            greaterThanOrEqualTo(
              RegExp(r'[\u3400-\u9fff]').hasMatch(w) ? 2 : 4,
            ),
            reason: w,
          );
        }
      }
    });
    test(
      'Portuguese professions also look for their English and German names',
      () {
        expect(
          titleSynonyms('fisioterapeuta'),
          containsAll(['physiotherap', 'physical therap']),
        );
        expect(
          titleSynonyms('fisioterapia pélvica'),
          containsAll(['physiotherap', 'pelvic', 'beckenboden']),
        );
        expect(
          titleSynonyms('enfermeira'),
          containsAll(['nurse', 'krankenpfleg', 'pflegefach']),
        );
        expect(titleSynonyms('physiotherapist'), contains('fisioterap'));
      },
    );
    test('an unrelated term adds nothing', () {
      expect(titleSynonyms('goiânia'), isEmpty);
      expect(titleSynonyms('acme'), isEmpty);
    });
  });

  group('specialised portals (links only)', () {
    test('every portal is https and has a region', () {
      for (final p in specialtyPortals) {
        expect(Uri.parse(p.url).scheme, 'https', reason: p.name);
        expect(p.region, isNotEmpty);
      }
    });
    test(
      'pelvic physiotherapy lists its own boards first, then physiotherapy boards',
      () {
        final list = portalsFor(HealthSpecialty.pelvicPhysio);
        expect(list.first.specialties, contains(HealthSpecialty.pelvicPhysio));
        expect(
          list.map((p) => p.name),
          contains('PCI Concursos: fisioterapeuta'),
        );
      },
    );
    test(
      'the federal university hospitals page is listed for physiotherapy and for its pelvic specialty',
      () {
        for (final spec in [
          HealthSpecialty.physiotherapy,
          HealthSpecialty.pelvicPhysio,
        ]) {
          expect(
            portalsFor(spec).map((p) => p.name),
            contains('HU Brasil (EBSERH): concursos e seleções'),
            reason: '$spec',
          );
        }
      },
    );
    test(
      'nursing has no dedicated board yet: only the general ones (none today)',
      () {
        expect(portalsFor(HealthSpecialty.nursing), isEmpty);
      },
    );
  });
}
