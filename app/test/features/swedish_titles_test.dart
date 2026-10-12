import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/health_specialty.dart';
import 'package:orbijob/features/search/domain/job_area.dart';
import 'package:orbijob/features/search/domain/search_synonyms.dart';

// Titles are real Platsbanken (Arbetsförmedlingen) headlines read on 2026-10-12.
void main() {
  group('Swedish titles are filed by the same deterministic rules', () {
    test('clinical professions', () {
      expect(
        HealthSpecialty.of('Fysioterapeut/ Sjukgymnast hemrehabilitering'),
        [HealthSpecialty.physiotherapy],
      );
      expect(HealthSpecialty.of('Fysioterapeut, deltid 50%'), [
        HealthSpecialty.physiotherapy,
      ]);
      expect(HealthSpecialty.of('Bäckenbottenfysioterapeut till kliniken'), [
        HealthSpecialty.physiotherapy,
        HealthSpecialty.pelvicPhysio,
      ]);
      expect(
        HealthSpecialty.of('Legitimerad sjuksköterska till vårdavdelning'),
        [HealthSpecialty.nursing],
      );
      expect(HealthSpecialty.of('Arbetsterapeut till hemrehab'), [
        HealthSpecialty.occupationalTherapy,
      ]);
      expect(HealthSpecialty.of('Psykolog till barnpsykiatrin'), [
        HealthSpecialty.psychology,
      ]);
      expect(HealthSpecialty.of('Logoped'), [HealthSpecialty.speechTherapy]);
    });

    test(
      'a pelvic title that is not a physiotherapist stays out of pelvic physio',
      () {
        expect(
          HealthSpecialty.pelvicPhysio.matches('Bäckenbottenultraljud, läkare'),
          isFalse,
        );
      },
    );

    test('non-clinical titles of a health employer are not clinicians', () {
      expect(HealthSpecialty.of('Receptionist på fysioterapiklinik'), isEmpty);
      expect(HealthSpecialty.of('Säljare inom medicinteknik'), isEmpty);
    });

    test('areas', () {
      expect(JobArea.of('Svetsare till MVUSAB'), contains(JobArea.industry));
      expect(
        JobArea.of('Butiksmedarbetare (extrajobb), Hemköp'),
        contains(JobArea.sales),
      );
      expect(JobArea.of('Lastbilsförare C-kort'), contains(JobArea.logistics));
      expect(
        JobArea.of('Förskollärare till avdelning Björnen'),
        contains(JobArea.education),
      );
      expect(JobArea.of('Android Developer'), contains(JobArea.technology));
      expect(JobArea.of('Systemutvecklare .NET'), contains(JobArea.technology));
      expect(
        JobArea.of('Snickare till byggprojekt'),
        contains(JobArea.construction),
      );
      expect(JobArea.of('Skolkurator'), contains(JobArea.public));
    });

    test(
      'a Swedish search term is widened to the other languages and back',
      () {
        expect(titleSynonyms('sjukgymnast'), contains('physiotherap'));
        expect(titleSynonyms('fysioterapeut'), contains('fisioterap'));
        expect(titleSynonyms('physiotherapist'), contains('sjukgymnast'));
        expect(titleSynonyms('nurse'), contains('sjuksköterska'));
        expect(titleSynonyms('teacher'), contains('lärare'));
        expect(titleSynonyms('pelvic floor'), contains('bäckenbotten'));
      },
    );
  });
}
