// OrbiJob 11.0: a recommendation must say how close the profession really is. Same profession, same occupation group, a related profession,
// only the same general area, and an incompatible one are different things; sharing "health" or "engineering" is never enough.
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/recommendations/domain/profession_groups.dart';
import 'package:orbijob/features/recommendations/domain/recommendation.dart';
import 'package:orbijob/features/recommendations/domain/recommender.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';

final _r = Recommender(now: () => DateTime.utc(2026, 10, 14, 12));

JobPosting _job(String title, {String? country}) => JobPosting(
  source: 'jobicy',
  externalId: title,
  company: 'Acme',
  title: title,
  originalUrl: 'https://example.com/x',
  country: country,
);

RecommendationProfile _p(
  String profession, {
  Set<String> interest = const {'DE'},
}) => RecommendationProfile(
  professions: [profession],
  interestCountries: interest,
);

ReasonKind? _kind(String profession, String title, {String? country = 'DE'}) {
  final r = _r.evaluate(_p(profession), _job(title, country: country));
  return r?.reasons
      .firstWhere(
        (x) =>
            x.kind != ReasonKind.countryOfInterest &&
            x.kind != ReasonKind.recent,
        orElse: () => r.reasons.first,
      )
      .kind;
}

void main() {
  group('physiotherapist is not offered doctors', () {
    test(
      'doctor, psychiatrist, nurse: nothing, even in a country of interest',
      () {
        for (final t in [
          'Arzt (m/w/d) Innere Medizin',
          'Facharzt Psychiatrie',
          'Physician Assistant',
          'Fachkrankenpfleger Psychiatrie',
          'Médico Generalista',
        ]) {
          expect(_kind('Fisioterapeuta', t), isNull, reason: t);
        }
      },
    );
    test('the profession in another language is the same profession', () {
      expect(
        _kind('Fisioterapeuta', 'Physiotherapist (m/w/d)'),
        ReasonKind.professionSynonym,
      );
      expect(
        _kind('Fisioterapeuta', 'Fisioterapeuta'),
        ReasonKind.professionExact,
      );
    });
    test(
      'a listing that names several professions, one of them hers, stays',
      () {
        expect(
          _kind('Physiotherapist', 'Physiotherapist / Occupational Therapist'),
          isNotNull,
        );
      },
    );
    test('the specialty matters: "pelvic" is not ignored, and a general physiotherapist job is the same GROUP, not the same specialty', () {
      expect(
        _kind('Fisioterapeuta pélvica', 'Pelvic Health Physiotherapist'),
        isNot(ReasonKind.professionGroup),
      );
      expect(
        _kind('Fisioterapeuta pélvica', 'Physiotherapist (m/w/d)'),
        ReasonKind.professionGroup,
      );
    });
  });

  group('nurse versus caregiver and assistants', () {
    test('a nurse is not offered care or assistant jobs', () {
      for (final t in [
        'Caregiver',
        'Nursing Assistant',
        'Auxiliar de enfermagem',
        'Pflegehelfer (m/w/d)',
        'Cuidador de idosos',
        'Healthcare Assistant',
      ]) {
        expect(_kind('Enfermeiro', t), isNull, reason: t);
      }
    });
    test('but a nurse in any of the languages is', () {
      expect(_kind('Enfermeiro', 'Registered Nurse - ICU'), isNotNull);
      expect(
        _kind('Enfermeira', 'Gesundheits- und Krankenpfleger (m/w/d)'),
        isNotNull,
      );
      expect(_kind('Enfermeiro', 'Sjuksköterska till vårdcentral'), isNotNull);
    });
    test('and the assistant is not offered nurse jobs either', () {
      expect(_kind('Auxiliar de enfermagem', 'Registered Nurse'), isNull);
    });
  });

  group('engineering: the qualifier decides the function', () {
    test('civil engineer versus software engineer', () {
      expect(_kind('Engenheiro civil', 'Software Engineer'), isNull);
      expect(_kind('Civil Engineer', 'Software Engineer'), isNull);
      expect(_kind('Software Engineer', 'Civil Engineer'), isNull);
      expect(_kind('Engenheiro civil', 'Civil Engineer (m/w/d)'), isNotNull);
      expect(_kind('Engenheiro civil', 'Bauingenieur'), isNotNull);
    });
    test('electrician versus electrical engineer', () {
      expect(_kind('Eletricista', 'Engenheiro Eletricista'), isNull);
      expect(_kind('Electrician', 'Electrical Engineer'), isNull);
      expect(
        _kind('Eletricista', 'Eletricista Industrial'),
        ReasonKind.professionExact,
      );
      expect(_kind('Eletricista', 'Elektriker (m/w/d)'), isNotNull);
    });
  });

  group('technology', () {
    test('Flutter developer and software engineer are RELATED, in both directions, and never "the same"', () {
      expect(
        _kind('Flutter Developer', 'Software Engineer'),
        ReasonKind.professionRelated,
      );
      expect(
        _kind('Software Engineer', 'Flutter Developer'),
        ReasonKind.professionRelated,
      );
      expect(
        _kind('Desenvolvedor Flutter', 'Mobile Engineer'),
        ReasonKind.professionGroup, // the same occupation group, in other words
      );
      final r = _r.evaluate(
        _p('Flutter Developer'),
        _job('Senior Flutter Developer', country: 'DE'),
      )!;
      expect(r.reasons.first.kind, ReasonKind.professionExact);
      expect(
        r.score,
        greaterThan(
          _r
              .evaluate(
                _p('Flutter Developer'),
                _job('Software Engineer', country: 'DE'),
              )!
              .score,
        ),
      );
    });
    test(
      'a related profession is not offered for an unrelated technology role',
      () {
        expect(_kind('Flutter Developer', 'Data Scientist'), isNull);
        expect(_kind('Flutter Developer', 'Network Administrator'), isNull);
      },
    );
  });

  group('teaching', () {
    test('a teacher is not offered teaching-assistant jobs', () {
      for (final t in [
        'Teaching Assistant',
        'Assistente de ensino',
        'Teacher Assistant',
        'Lehrassistent (m/w/d)',
        'Classroom Assistant',
      ]) {
        expect(_kind('Professor', t, country: 'DE'), isNull, reason: t);
      }
      expect(_kind('Teacher', 'Teaching Assistant'), isNull);
    });
    test('a teacher is offered teacher jobs', () {
      expect(
        _kind('Professor', 'Professor de Matemática'),
        ReasonKind.professionExact,
      );
      expect(_kind('Teacher', 'Lehrer (m/w/d) Mathematik'), isNotNull);
    });
  });

  group('the general area alone', () {
    test('never recommends a listing, however many countries match', () {
      for (final e in {
        'Accountant': 'Marketing Manager',
        'Dentist': 'Physician',
        'Cook': 'Waiter',
        'Welder': 'Plumber',
      }.entries) {
        expect(_kind(e.key, e.value), isNull, reason: '${e.key} / ${e.value}');
      }
    });
    test('but an extra reason can mention it when something real agrees', () {
      final p = RecommendationProfile(
        professions: const ['Dentist'],
        skills: const ['Endodontics'],
        interestCountries: const {'DE'},
      );
      final r = _r.evaluate(
        p,
        JobPosting(
          source: 'x',
          externalId: '1',
          company: 'C',
          title: 'Physician',
          originalUrl: 'https://example.com',
          country: 'DE',
          description: 'Endodontics clinic',
        ),
      );
      expect(r, isNotNull);
      expect(r!.reasons.map((e) => e.kind), contains(ReasonKind.skills));
    });
  });

  group('profession groups (ESCO + the few curated generic words)', () {
    test('known names resolve to an ISCO group and the longest name wins', () {
      expect(occupationOf('Fisioterapeuta').codes, {'2264'});
      expect(occupationOf('Engenheiro civil').codes, {'2142'});
      expect(occupationOf('Engenheiro eletricista').codes, {'2151'});
      expect(occupationOf('Eletricista').codes, {'7411'});
      expect(occupationOf('Nurse').codes, {'2221'});
      expect(occupationOf('Nursing assistant').codes, {'5321'});
      expect(occupationOf('Teacher').codes, {'2330'});
      expect(occupationOf('Teaching assistant').codes, {'5312'});
      expect(occupationOf('Banana').known, isFalse);
    });
    test('a modifier is not a second occupation, two professions are two', () {
      expect(mentionsIn('Engenheiro Eletricista').length, 1);
      expect(mentionsIn('Physiotherapist / Occupational Therapist').length, 2);
    });
    test('relations', () {
      expect(relationOf({'2264'}, {'2264'}), Relation.sameGroup);
      expect(relationOf({'2514'}, {'2512'}), Relation.related);
      expect(relationOf({'2264'}, {'2211'}), Relation.areaOnly);
      expect(relationOf({'2221'}, {'5321'}), Relation.none);
      expect(relationOf({}, {'2221'}), Relation.none);
    });
  });
}
