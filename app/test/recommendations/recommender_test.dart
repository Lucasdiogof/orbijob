import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/preferences/domain/user_preferences.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/features/recommendations/domain/recommendation.dart';
import 'package:orbijob/features/recommendations/domain/recommender.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';

final _now = DateTime.utc(2026, 10, 13, 12);
final _r = Recommender(now: () => _now);

JobPosting job(
  String id,
  String title, {
  String? country,
  String? city,
  WorkMode mode = WorkMode.unspecified,
  String? language,
  List<String> geo = const [],
  int? daysAgo,
  String? description,
}) => JobPosting(
  source: 'jobicy',
  externalId: id,
  company: 'Acme',
  title: title,
  originalUrl: 'https://example.com/$id',
  country: country,
  city: city,
  workMode: mode,
  language: language,
  geoRestrictions: geo,
  description: description,
  publishedAt: daysAgo == null ? null : _now.subtract(Duration(days: daysAgo)),
);

RecommendationProfile profile({
  List<String> professions = const [],
  List<String> skills = const [],
  Set<String> interest = const {},
  String? residence,
  String? city,
  String? workMode,
  Set<String> languages = const {},
  Set<MustHave> must = const {},
}) => RecommendationProfile(
  professions: professions,
  skills: skills,
  interestCountries: interest,
  residence: residence,
  city: city,
  workMode: workMode,
  languages: languages,
  mustHave: must,
);

Recommendation? one(RecommendationProfile p, JobPosting j) => _r.evaluate(p, j);

void main() {
  group('no single source dominates', () {
    JobPosting from(String source, String id) => JobPosting(
      source: source,
      externalId: id,
      company: 'Acme',
      title: 'Registered Nurse',
      originalUrl: 'https://example.com/$source/$id',
      publishedAt: _now.subtract(Duration(hours: int.parse(id))),
    );
    test('at most half of the list from one source while others have relevant jobs', () {
      final jobs = [
        for (var i = 1; i <= 20; i++) from('big', '$i'),
        for (var i = 30; i <= 34; i++) from('small', '$i'),
      ];
      final top = _r.rank(profile(professions: ['nurse']), jobs, limit: 10);
      expect(top, hasLength(10));
      expect(top.where((r) => r.job.source == 'big'), hasLength(5));
      expect(top.where((r) => r.job.source == 'small'), hasLength(5));
    });
    test('when there is not enough variety nothing relevant is dropped', () {
      final jobs = [
        for (var i = 1; i <= 8; i++) from('big', '$i'),
        from('small', '40'),
      ];
      final top = _r.rank(profile(professions: ['nurse']), jobs, limit: 10);
      expect(top, hasLength(9));
      expect(top.map((r) => r.job.externalId).take(5), [
        '1',
        '2',
        '3',
        '4',
        '5',
      ]);
    });
  });

  group('any profession, not only technology', () {
    test('a nurse is matched to nursing jobs in two languages and not to unrelated ones', () {
      final p = profile(professions: ['Enfermeira']);
      expect(
        one(p, job('1', 'Enfermeiro(a) de UTI'))!.reasons.first.kind,
        ReasonKind.professionClose,
      );
      expect(
        one(p, job('2', 'Registered Nurse'))!.reasons.first.kind,
        ReasonKind.professionSynonym,
      );
      expect(one(p, job('3', 'Backend Developer')), isNull);
      expect(one(p, job('4', 'Welder')), isNull);
    });

    test('an electrician, an accountant, a cook: the same rules', () {
      expect(
        one(
          profile(professions: ['Eletricista']),
          job('1', 'Eletricista Industrial'),
        )!.reasons.first.kind,
        ReasonKind.professionExact,
      );
      expect(
        one(
          profile(professions: ['Accountant']),
          job('2', 'Senior Accountant (Tax)'),
        )!.score,
        greaterThan(0),
      );
      expect(
        one(
          profile(professions: ['Buchhalter']),
          job('3', 'Accountant'),
        )!.reasons.first.kind,
        ReasonKind.professionSynonym,
      );
      expect(
        one(
          profile(professions: ['Cozinheiro']),
          job('4', 'Cozinheiro(a)'),
        )!.reasons.first.kind,
        ReasonKind.professionExact,
      );
      expect(
        one(profile(professions: ['Cook']), job('5', 'Software Engineer')),
        isNull,
      );
    });

    test('two different engineering fields are not the same profession', () {
      final p = profile(professions: ['Software Engineer']);
      expect(one(p, job('1', 'Mechanical Engineer')), isNull);
      expect(
        one(p, job('2', 'Senior Software Engineer'))!.reasons.first.kind,
        ReasonKind.professionExact,
      );
    });

    test('another title of the same ESCO occupation group is said so ("same occupation group"), and scores below the profession itself', () {
      final p = profile(professions: ['Accountant'], interest: {'DE'});
      final r = one(p, job('1', 'Financial Controller', country: 'DE'));
      expect(r!.reasons.first.kind, ReasonKind.professionGroup);
      expect(
        r.score,
        lessThan(one(p, job('2', 'Accountant', country: 'DE'))!.score),
      );
    });

    test('a title that only shares the general area is not recommended, with or without a country of interest', () {
      final p = profile(professions: ['Accountant'], interest: {'DE'});
      expect(one(p, job('0', 'Marketing Manager')), isNull);
      expect(one(p, job('1', 'Marketing Manager', country: 'DE')), isNull);
    });

    test('accents and capitals do not matter', () {
      final p = profile(professions: ['TÉCNICO de enfermagem']);
      expect(
        one(p, job('1', 'Tecnico De Enfermagem Noturno'))!.reasons.first.kind,
        ReasonKind.professionExact,
      );
      expect(normalizeForMatch('Çà Ñandú-Über'), 'ca nandu uber');
    });
  });

  group('skills', () {
    test('skills found as whole words in the title or text count; fragments do not', () {
      final p = profile(skills: ['SQL', 'Excel', 'Python']);
      final yes = one(
        p,
        job('1', 'Data Analyst', description: 'We use SQL and excel daily'),
      )!;
      expect(yes.reasons.first.kind, ReasonKind.skills);
      expect(yes.reasons.first.items, ['SQL', 'Excel']);
      expect(
        one(p, job('2', 'Analyst', description: 'mysqldump tooling')),
        isNull,
      );
    });
  });

  group('place', () {
    final nurse = ['Nurse'];
    test('interest countries beat residence; remote jobs open to a country of the person count; a silent listing is kept with a note', () {
      final p = profile(professions: nurse, interest: {'DE'}, residence: 'BR');
      expect(
        one(p, job('1', 'Nurse', country: 'DE'))!.reasons.map((r) => r.kind),
        contains(ReasonKind.countryOfInterest),
      );
      expect(
        one(p, job('2', 'Nurse', country: 'BR'))!.reasons.map((r) => r.kind),
        contains(ReasonKind.countryOfResidence),
      );
      final remote = one(
        p,
        job('3', 'Nurse', mode: WorkMode.remote, geo: ['BR']),
      )!;
      expect(
        remote.reasons.map((r) => r.kind),
        contains(ReasonKind.remoteEligible),
      );
      final any = one(
        p,
        job('4', 'Nurse', mode: WorkMode.remote, geo: ['Anywhere']),
      )!;
      expect(
        any.reasons.map((r) => r.kind),
        contains(ReasonKind.remoteAnywhere),
      );
      final silent = one(p, job('5', 'Nurse'))!;
      expect(
        silent.caveats.map((c) => c.kind),
        contains(CaveatKind.locationUnknown),
      );
      final elsewhere = one(p, job('6', 'Nurse', country: 'JP'))!;
      expect(
        elsewhere.score,
        lessThan(one(p, job('7', 'Nurse', country: 'DE'))!.score),
      );
    });

    test('the same city adds to the place score', () {
      final p = profile(professions: nurse, residence: 'BR', city: 'Goiânia');
      final a = one(p, job('1', 'Nurse', country: 'BR', city: 'Goiania'))!;
      final b = one(p, job('2', 'Nurse', country: 'BR', city: 'Recife'))!;
      expect(a.reasons.map((r) => r.kind), contains(ReasonKind.city));
      expect(a.score, greaterThanOrEqualTo(b.score));
    });
  });

  group('work mode and language', () {
    test('a matching work mode adds points, a mismatch does not subtract, an unstated one is flagged', () {
      final p = profile(professions: ['Nurse'], workMode: 'remote');
      final remote = one(p, job('1', 'Nurse', mode: WorkMode.remote))!;
      final onsite = one(p, job('2', 'Nurse', mode: WorkMode.onsite))!;
      final unstated = one(p, job('3', 'Nurse'))!;
      expect(remote.score, greaterThan(onsite.score));
      expect(onsite.score, unstated.score);
      expect(
        unstated.caveats.map((c) => c.kind),
        contains(CaveatKind.workModeUnstated),
      );
    });

    test('a listing in another language is kept and flagged, one in the profile languages is rewarded', () {
      final p = profile(professions: ['Nurse'], languages: {'pt', 'en'});
      final de = one(p, job('1', 'Nurse', language: 'de'))!;
      expect(
        de.caveats.map((c) => c.kind),
        contains(CaveatKind.languageDiffers),
      );
      final en = one(p, job('2', 'Nurse', language: 'en-GB'))!;
      expect(en.reasons.map((r) => r.kind), contains(ReasonKind.language));
      expect(en.score, greaterThan(de.score));
    });
  });

  group('must-haves versus nice-to-haves', () {
    test('a preference never removes a job; a must-have removes only what contradicts it', () {
      final nice = profile(professions: ['Nurse'], workMode: 'remote');
      expect(one(nice, job('1', 'Nurse', mode: WorkMode.onsite)), isNotNull);
      final must = profile(
        professions: ['Nurse'],
        workMode: 'remote',
        must: {MustHave.workMode},
      );
      expect(one(must, job('1', 'Nurse', mode: WorkMode.onsite)), isNull);
      expect(one(must, job('2', 'Nurse', mode: WorkMode.remote)), isNotNull);
      expect(
        one(must, job('3', 'Nurse')),
        isNotNull,
        reason: 'a listing that says nothing is not a contradiction',
      );
    });

    test('country must-have: other countries go, matching, eligible-remote and silent ones stay', () {
      final p = profile(
        professions: ['Nurse'],
        interest: {'DE'},
        residence: 'BR',
        must: {MustHave.country},
      );
      expect(one(p, job('1', 'Nurse', country: 'JP')), isNull);
      expect(one(p, job('2', 'Nurse', country: 'DE')), isNotNull);
      expect(
        one(p, job('3', 'Nurse', mode: WorkMode.remote, geo: ['Anywhere'])),
        isNotNull,
      );
      expect(
        one(p, job('4', 'Nurse', mode: WorkMode.remote, geo: ['US'])),
        isNull,
      );
      expect(one(p, job('5', 'Nurse')), isNotNull);
    });

    test(
      'language must-have: only listings written in another known language go',
      () {
        final p = profile(
          professions: ['Nurse'],
          languages: {'pt'},
          must: {MustHave.language},
        );
        expect(one(p, job('1', 'Nurse', language: 'de')), isNull);
        expect(one(p, job('2', 'Nurse', language: 'pt')), isNotNull);
        expect(one(p, job('3', 'Nurse')), isNotNull);
      },
    );

    test('a must-have with nothing to compare against is ignored (the profile is incomplete, not strict)', () {
      final p = profile(
        professions: ['Nurse'],
        must: {MustHave.workMode, MustHave.country, MustHave.language},
      );
      expect(
        one(
          p,
          job(
            '1',
            'Nurse',
            mode: WorkMode.onsite,
            country: 'JP',
            language: 'de',
          ),
        ),
        isNotNull,
      );
    });
  });

  group('incomplete profiles', () {
    test(
      'an empty profile recommends nothing (there is nothing to compare)',
      () {
        expect(profile().isEmpty, isTrue);
        expect(one(profile(), job('1', 'Nurse', daysAgo: 0)), isNull);
      },
    );

    test('a thin profile is scored on what it has: missing data never lowers the score', () {
      final thin = profile(professions: ['Nurse']);
      final full = profile(
        professions: ['Nurse'],
        workMode: 'remote',
        languages: {'pt'},
        interest: {'DE'},
      );
      final j = job('1', 'Registered Nurse', daysAgo: 1);
      expect(one(thin, j)!.score, greaterThanOrEqualTo(80));
      expect(
        one(full, j)!.score,
        lessThan(one(thin, j)!.score),
        reason:
            'more criteria, none met: honestly lower than "all we asked met"',
      );
      expect(one(thin, j)!.signals, lessThan(one(full, j)!.signals));
    });

    test('a profile with only a place and a work mode still gets relevant, not random, jobs', () {
      final p = profile(interest: {'PT'}, workMode: 'remote');
      expect(
        one(p, job('1', 'Anything', country: 'PT', mode: WorkMode.remote)),
        isNotNull,
      );
      expect(
        one(
          p,
          job(
            '2',
            'Anything',
            country: 'JP',
            mode: WorkMode.onsite,
            daysAgo: 0,
          ),
        ),
        isNull,
        reason: 'only "published recently" agrees',
      );
    });
  });

  group('honesty about eligibility', () {
    test('a restricted listing carries a reminder; nothing says the person qualifies', () {
      final p = profile(professions: ['Nurse'], residence: 'BR');
      final r = one(
        p,
        job('1', 'Nurse', mode: WorkMode.remote, geo: ['US', 'CA']),
      )!;
      final c = r.caveats.firstWhere(
        (c) => c.kind == CaveatKind.eligibilityRestricted,
      );
      expect(c.items, ['US', 'CA']);
      for (final reason in r.reasons) {
        expect(ReasonKind.values.map((k) => k.name), isNot(contains('visa')));
        expect(
          reason.kind,
          isNot(ReasonKind.remoteEligible),
          reason: 'US/CA are not the person\'s countries',
        );
      }
    });
  });

  group('ranking', () {
    test('deterministic: best score first, then newest, then a stable key', () {
      final p = profile(professions: ['Nurse'], interest: {'DE'});
      final jobs = [
        job('b', 'Nurse', country: 'DE', daysAgo: 20),
        job('a', 'Nurse', country: 'DE', daysAgo: 20),
        job('c', 'Nurse', country: 'DE', daysAgo: 1),
        job('d', 'Nurse', country: 'JP', daysAgo: 1),
      ];
      final first = _r.rank(p, jobs);
      final second = _r.rank(p, jobs.reversed);
      expect(first.map((e) => e.job.externalId), ['c', 'a', 'b', 'd']);
      expect(
        second.map((e) => e.job.externalId),
        first.map((e) => e.job.externalId),
      );
    });

    test('the same job twice is listed once; the limit applies', () {
      final p = profile(professions: ['Nurse']);
      final jobs = [
        for (var i = 0; i < 10; i++) job('$i', 'Nurse'),
        job('0', 'Nurse'),
      ];
      expect(_r.rank(p, jobs).length, 10);
      expect(_r.rank(p, jobs, limit: 3).length, 3);
    });

    test('score bands: strong, good, possible', () {
      final p = profile(
        professions: ['Nurse'],
        interest: {'DE'},
        workMode: 'remote',
        languages: {'en'},
      );
      final strong = one(
        p,
        job(
          '1',
          'Nurse',
          country: 'DE',
          mode: WorkMode.remote,
          language: 'en',
          daysAgo: 0,
        ),
      )!;
      expect(strong.fit, Fit.strong);
      final good = one(p, job('2', 'Nurse', country: 'DE', language: 'en'))!;
      expect(good.fit, anyOf(Fit.good, Fit.strong));
      final possible = one(p, job('3', 'Nursing Home Manager', country: 'JP'));
      expect(possible?.fit ?? Fit.possible, Fit.possible);
    });
  });

  group('the profile model', () {
    test('built from a stored profile, experiences and preferences', () {
      final stored = ProfessionalProfile(
        name: 'Ana',
        countryOfResidence: 'br',
        languages: const [
          ProfileLanguage(code: 'pt-BR'),
          ProfileLanguage(code: 'EN'),
        ],
        skills: const ['Triage', 'x'],
        personal: const {'headline': 'Enfermeira', 'city': 'Goiânia'},
        preferences: const {
          'workMode': 'hybrid',
          'mustHave': ['workMode', 'bogus', 'language'],
        },
      );
      final p = RecommendationProfile.from(stored, [
        Experience(
          profileId: 'p',
          company: 'A',
          title: 'Técnica de enfermagem',
          startDate: DateTime(2020),
        ),
        Experience(
          profileId: 'p',
          company: 'B',
          title: 'Enfermeira',
          startDate: DateTime(2023),
        ),
        Experience(
          profileId: 'p',
          company: 'C',
          title: 'Aux',
          startDate: DateTime(2018),
        ),
      ], const UserPreferences(countriesOfInterest: ['de', 'PT', 'xyz']));
      expect(p.professions, ['Enfermeira', 'Técnica de enfermagem', 'Aux']);
      expect(p.skills, ['Triage']);
      expect(p.interestCountries, {'DE', 'PT'});
      expect(p.residence, 'BR');
      expect(p.languages, {'pt', 'en'});
      expect(p.workMode, 'hybrid');
      expect(p.mustHave, {MustHave.workMode, MustHave.language});
      expect(
        RecommendationProfile.from(
          null,
          const [],
          const UserPreferences(),
        ).isEmpty,
        isTrue,
      );
    });

    test('copyWith keeps unknown preference keys and clears must-haves', () {
      const p = ProfessionalProfile(
        name: 'A',
        preferences: {'other': 1, 'workMode': 'remote'},
      );
      final a = p.copyWith(mustHave: {MustHave.country});
      expect(a.preferences['other'], 1);
      expect(a.mustHave, {MustHave.country});
      expect(
        a.copyWith(mustHave: <MustHave>{}).preferences.containsKey('mustHave'),
        isFalse,
      );
    });
  });
}
