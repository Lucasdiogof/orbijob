import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/preferences/domain/user_preferences.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/features/recommendations/domain/recommendation.dart';
import 'package:orbijob/features/recommendations/domain/recommender.dart';
import 'package:orbijob/features/recommendations/presentation/recommendations_cubit.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');

class _Catalogue implements SearchRepository {
  _Catalogue(this.jobs, {this.failAll = false});
  final List<JobPosting> jobs;
  final bool failAll;
  final asked = <String>[];

  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async {
    asked.add(
      '$query|${filters.countryCode ?? ''}|${filters.workModes.map((m) => m.name).join(',')}',
    );
    if (failAll) throw StateError('offline');
    final q = query.toLowerCase();
    final hits = jobs.where((j) {
      if (filters.countryCode != null && j.country != filters.countryCode) {
        return false;
      }
      if (filters.workModes.isNotEmpty &&
          !filters.workModes.contains(j.workMode)) {
        return false;
      }
      return q.isEmpty || j.title.toLowerCase().contains(q);
    });
    return SearchResult(
      jobs: [for (final j in hits) ScoredJob(j)],
      hasIntegratedSource: true,
    );
  }
}

JobPosting _job(
  String id,
  String title, {
  String? country,
  WorkMode mode = WorkMode.unspecified,
}) => JobPosting(
  source: 'jobicy',
  externalId: id,
  company: 'Acme',
  title: title,
  originalUrl: 'https://example.com/$id',
  country: country,
  workMode: mode,
);

void main() {
  group('RecommendationsCubit', () {
    test(
      'asks the catalogue for the profession, the countries and remote jobs, then ranks on the device',
      () async {
        final repo = _Catalogue([
          _job('1', 'Registered Nurse', country: 'DE'),
          _job('2', 'Nurse Practitioner', country: 'JP'),
          _job('3', 'Backend Developer', country: 'DE'),
          _job('4', 'Nurse (remote triage)', mode: WorkMode.remote),
        ]);
        final c = RecommendationsCubit(repo);
        await c.refresh(
          const RecommendationProfile(
            professions: ['Nurse'],
            interestCountries: {'DE'},
            workMode: 'remote',
          ),
        );
        expect(c.state.status, RecStatus.ready);
        expect(
          repo.asked.toSet(),
          containsAll(['Nurse||', '|DE|', '||remote']),
        );
        expect(c.state.items.map((r) => r.job.externalId), ['1', '4', '2']);
        expect(
          c.state.items.first.reasons.map((r) => r.kind),
          contains(ReasonKind.countryOfInterest),
        );
        await c.close();
      },
    );

    test(
      'the same profile does not ask again; a changed one does; force always does',
      () async {
        final repo = _Catalogue([_job('1', 'Nurse', country: 'DE')]);
        final c = RecommendationsCubit(repo);
        const p = RecommendationProfile(professions: ['Nurse']);
        await c.refresh(p);
        final n = repo.asked.length;
        await c.refresh(p);
        expect(repo.asked.length, n);
        await c.refresh(
          const RecommendationProfile(
            professions: ['Nurse'],
            workMode: 'hybrid',
          ),
        );
        expect(repo.asked.length, greaterThan(n));
        final m = repo.asked.length;
        await c.refresh(
          const RecommendationProfile(
            professions: ['Nurse'],
            workMode: 'hybrid',
          ),
          force: true,
        );
        expect(repo.asked.length, greaterThan(m));
        await c.close();
      },
    );

    test(
      'nothing to compare, nothing matching, offline and not configured are different answers',
      () async {
        final c = RecommendationsCubit(_Catalogue([_job('1', 'Welder')]));
        await c.refresh(null);
        expect(c.state.status, RecStatus.needsProfile);
        await c.refresh(const RecommendationProfile());
        expect(c.state.status, RecStatus.needsProfile);
        await c.refresh(const RecommendationProfile(professions: ['Nurse']));
        expect(c.state.status, RecStatus.empty);
        final off = RecommendationsCubit(_Catalogue(const [], failAll: true));
        await off.refresh(const RecommendationProfile(professions: ['Nurse']));
        expect(off.state.status, RecStatus.failure);
        final none = RecommendationsCubit(null);
        await none.refresh(const RecommendationProfile(professions: ['Nurse']));
        expect(none.state.status, RecStatus.notConfigured);
        await c.close();
        await off.close();
        await none.close();
      },
    );

    test('a thin profile is flagged so the screen can say so', () async {
      final c = RecommendationsCubit(
        _Catalogue([_job('1', 'Anything', country: 'PT')]),
      );
      await c.refresh(const RecommendationProfile(interestCountries: {'PT'}));
      expect(c.state.status, RecStatus.ready);
      expect(c.state.thin, isTrue);
      await c.close();
    });
  });

  group('on screen', () {
    Future<Fakes> signedIn(
      WidgetTester t, {
      ProfessionalProfile? profile,
      UserPreferences? prefs,
      Size size = const Size(390, 1400),
    }) async {
      final auth = FakeAuth()..currentUser = _user;
      final fakes = Fakes(auth: auth);
      if (profile != null) {
        fakes.profiles.profileRows.add(
          ProfessionalProfile(
            id: 'p1',
            name: profile.name,
            personal: profile.personal,
            preferences: profile.preferences,
            languages: profile.languages,
            skills: profile.skills,
            countryOfResidence: profile.countryOfResidence,
          ),
        );
      }
      if (prefs != null) fakes.preferences.stored = prefs;
      await pumpApp(
        t,
        repo: PreviewSearchRepository(),
        auth: auth,
        fakes: fakes,
        size: size,
      );
      return fakes;
    }

    testWidgets(
      'Home explains why a job is recommended, in plain words, without promising eligibility',
      (t) async {
        await signedIn(
          t,
          profile: const ProfessionalProfile(
            name: 'Ana',
            personal: {'headline': 'Fisioterapeuta'},
          ),
          prefs: const UserPreferences(countriesOfInterest: ['DE']),
        );
        expect(find.text('Recommended for you'), findsOneWidget);
        expect(find.text('Beckenboden-Physiotherapeut:in'), findsNWidgets(2));
        expect(find.text('Strong match'), findsOneWidget);
        expect(
          find.textContaining(
            'Same profession, another language: Fisioterapeuta',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Why this job?'),
          findsOneWidget,
          reason: 'only her profession is recommended',
        );
        await t.tap(find.text('Why this job?'));
        await t.pumpAndSettle();
        expect(find.text('Why you see this job'), findsOneWidget);
        expect(
          find.textContaining('In Germany, one of your countries of interest'),
          findsNWidgets(2),
        );
        expect(
          find.textContaining('does not check visas, work permits'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a hidden recommendation disappears from the list', (t) async {
      final fakes = await signedIn(
        t,
        profile: const ProfessionalProfile(
          name: 'Ana',
          personal: {'headline': 'Fisioterapeuta'},
        ),
        prefs: const UserPreferences(countriesOfInterest: ['DE']),
      );
      await t.tap(
        find.byTooltip('More actions for Beckenboden-Physiotherapeut:in').first,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Hide this job'));
      await t.pumpAndSettle();
      expect(fakes.hidden.rows, isNotEmpty);
      expect(find.text('Beckenboden-Physiotherapeut:in'), findsNothing);
    });

    testWidgets(
      'a nurse-to-be with no data yet is asked to fill the profile; nothing is invented',
      (t) async {
        await signedIn(t);
        expect(find.text('Tell us what you do'), findsOneWidget);
        expect(find.text('Complete my profile'), findsOneWidget);
      },
    );

    testWidgets('signed out the section invites to sign in', (t) async {
      final auth = FakeAuth();
      await pumpApp(
        t,
        repo: PreviewSearchRepository(),
        auth: auth,
        fakes: Fakes(auth: auth),
        size: const Size(390, 1400),
      );
      expect(find.text('Tell us what you do'), findsOneWidget);
      expect(
        find.textContaining('Sign in and fill in your profile'),
        findsOneWidget,
      );
    });
  });
}
