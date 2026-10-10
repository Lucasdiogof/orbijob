import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/user_scope.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/favorites/domain/favorites_repository.dart';
import 'package:orbijob/features/search/data/job_snapshot.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/features/search/presentation/cubit/search_cubit.dart';
import 'package:orbijob/preview/in_memory_favorites.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

// Widget tests over the real app with an in-memory catalogue. They check what the user sees; the HTTP layer is covered
// by test/supabase/job_catalog_test.dart and the table/policy by the Worker's PGlite tests. Nothing here is a remote test.

JobPosting job(
  String id, {
  String company = 'Juniper Square',
  bool salary = true,
  List<String> geo = const ['US'],
  String? description = 'Plain text description of the role.',
}) => JobPosting(
  source: 'jobicy',
  externalId: id,
  company: company,
  title: 'Account Executive $id',
  originalUrl: 'https://jobicy.com/jobs/$id',
  applyUrl: 'https://jobicy.com/jobs/$id',
  country: geo.length == 1 ? geo.first : null,
  workMode: WorkMode.remote,
  salaryMin: salary ? 120000 : null,
  salaryMax: salary ? 145000 : null,
  salaryCurrency: salary ? 'USD' : null,
  salaryPeriod: salary ? SalaryPeriod.year : null,
  publishedAt: DateTime.now().subtract(const Duration(days: 2)),
  sourceName: 'Jobicy',
  geoRestrictions: geo,
  description: description,
);

class CatalogRepo implements SearchRepository {
  CatalogRepo(this.all, {this.emptyWhenFiltered = false});
  final List<JobPosting> all;
  final bool emptyWhenFiltered;
  final calls = <(String, JobFilters, int)>[];
  Object? failNext;

  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async {
    calls.add((query, filters, offset));
    if (failNext != null) {
      final e = failNext!;
      failNext = null;
      throw e;
    }
    if (emptyWhenFiltered && filters.isActive) {
      return const SearchResult(jobs: [], hasIntegratedSource: true);
    }
    final slice = all.skip(offset).take(limit + 1).toList();
    return SearchResult(
      jobs: [for (final j in slice.take(limit)) ScoredJob(j)],
      hasIntegratedSource: true,
      hasMore: slice.length > limit,
    );
  }
}

/// Stands in for the url_launcher plugin (the test host has none): records the URLs and answers [opens].
List<String> mockLauncher(WidgetTester t, {required bool opens}) {
  final urls = <String>[];
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    if (call.method == 'launch') {
      urls.add((call.arguments as Map)['url'] as String);
    }
    return opens;
  });
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  return urls;
}

/// Favourites kept per signed-in user, like the real table under Row Level Security.
class PerUserFavorites implements FavoritesRepository {
  PerUserFavorites(this.auth);
  final FakeAuth auth;
  final _byUser = <String, Map<String, JobPosting>>{};
  Map<String, JobPosting> get _mine {
    final id = auth.currentUser?.id;
    if (id == null) throw const NotSignedInException();
    return _byUser.putIfAbsent(id, () => {});
  }

  @override
  Future<List<JobPosting>> list() async => _mine.values.toList();
  @override
  Future<void> add(JobPosting j) async => _mine[jobKey(j)] = j;
  @override
  Future<void> remove(JobPosting j) async => _mine.remove(jobKey(j));
}

Future<void> openExplore(WidgetTester t) async {
  await t.tap(find.text('Explore'));
  await t.pumpAndSettle();
}

Future<void> searchFor(WidgetTester t, String q) async {
  await openExplore(t);
  await t.enterText(find.byType(TextField), q);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

/// Brings a filter chip into view inside the (scrollable) panel and taps it.
Future<void> tapChip(WidgetTester t, String label) async {
  final f = find.widgetWithText(InkWell, label).first;
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Finder get resultsScrollable => find
    .descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets(
    'a catalogue job shows source, company, place, salary and date; a missing salary draws nothing',
    (t) async {
      final repo = CatalogRepo([
        job('1'),
        job('2', salary: false, company: ''),
      ]);
      await pumpApp(t, repo: repo);
      await searchFor(t, 'account');
      expect(find.text('Account Executive 1'), findsOneWidget);
      expect(find.text('Juniper Square'), findsOneWidget);
      expect(
        find.textContaining('120,000–145,000'),
        findsOneWidget,
        reason: 'valid salary is shown',
      );
      expect(
        find.textContaining('Source: Jobicy'),
        findsNWidgets(2),
        reason: 'attribution on every card',
      );
      expect(find.text('Remote'), findsNWidgets(2));
      // the job without salary draws no figure at all (only the first one has "120,000")
      expect(find.textContaining('120,000'), findsOneWidget);
      // the job without a company draws no empty company line, and still renders its title
      expect(find.text('Account Executive 2'), findsOneWidget);
      expect(find.text(''), findsNothing);
    },
  );

  testWidgets(
    'eligibility is kept: a remote job tied to no country shows where applicants must be',
    (t) async {
      final repo = CatalogRepo([
        job('1', geo: ['CA', 'US']),
      ]);
      await pumpApp(t, repo: repo);
      await searchFor(t, 'account');
      expect(find.text('CA, US'), findsOneWidget);
    },
  );

  testWidgets(
    'idle Explore offers the newest jobs; the real catalogue answers with no search term',
    (t) async {
      final repo = CatalogRepo([job('1'), job('2')]);
      await pumpApp(t, repo: repo);
      await openExplore(t);
      await t.tap(find.text('Show latest jobs'));
      await t.pumpAndSettle();
      expect(repo.calls.single.$1, '');
      expect(find.text('Account Executive 1'), findsOneWidget);
      expect(
        find.text('2 results'),
        findsOneWidget,
        reason: 'no more pages: the count is exact',
      );
    },
  );

  testWidgets(
    '"Show more" appends the next page; the header never claims a catalogue total while more exist',
    (t) async {
      final repo = CatalogRepo([for (var i = 1; i <= 25; i++) job('$i')]);
      await pumpApp(t, repo: repo);
      await searchFor(t, 'account');
      expect(find.text('Showing 20 jobs'), findsOneWidget);
      expect(find.textContaining('results'), findsNothing);
      await t.scrollUntilVisible(
        find.text('Show more'),
        400,
        scrollable: resultsScrollable,
      );
      await t.tap(find.text('Show more'));
      await t.pumpAndSettle();
      expect(repo.calls.last.$3, 20);
      await t.scrollUntilVisible(
        find.text('Account Executive 25'),
        400,
        scrollable: resultsScrollable,
      );
      expect(
        find.text('Show more'),
        findsNothing,
        reason: 'last page: no button',
      );
      await t.scrollUntilVisible(
        find.text('25 results'),
        -600,
        scrollable: resultsScrollable,
      );
      expect(
        find.text('25 results'),
        findsOneWidget,
        reason: 'all pages loaded: the count is exact',
      );
    },
  );

  testWidgets(
    'a failed "Show more" keeps what was loaded and offers to retry',
    (t) async {
      final repo = CatalogRepo([for (var i = 1; i <= 25; i++) job('$i')]);
      await pumpApp(t, repo: repo);
      await searchFor(t, 'account');
      await t.scrollUntilVisible(
        find.text('Show more'),
        400,
        scrollable: resultsScrollable,
      );
      repo.failNext = Exception('offline');
      await t.tap(find.text('Show more'));
      await t.pumpAndSettle();
      expect(find.text('Could not load more jobs.'), findsOneWidget);
      expect(
        find.text('Account Executive 20'),
        findsOneWidget,
        reason: 'the first page is still there',
      );
      await t.ensureVisible(find.text('Try again'));
      await t.pumpAndSettle();
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('Could not load more jobs.'), findsNothing);
      expect(
        repo.calls.last.$3,
        20,
        reason: 'retry asks for the same page again',
      );
      await t.scrollUntilVisible(
        find.text('Account Executive 25'),
        400,
        scrollable: resultsScrollable,
      );
      expect(find.text('Account Executive 25'), findsOneWidget);
    },
  );

  testWidgets(
    'filters: the panel opens, a chip reloads the list with that filter, the button counts, clear resets',
    (t) async {
      final repo = CatalogRepo([job('1'), job('2')]);
      await pumpApp(t, repo: repo);
      await searchFor(t, 'account');
      await t.tap(find.text('Filters'));
      await t.pumpAndSettle();
      await tapChip(t, 'Remote');
      expect(repo.calls.last.$2.workModes, {WorkMode.remote});
      expect(repo.calls.last.$3, 0);
      expect(find.text('Filters (1)'), findsOneWidget);
      await tapChip(t, 'Last 7 days');
      expect(repo.calls.last.$2.publishedWithinDays, 7);
      await tapChip(t, 'Only with salary');
      expect(repo.calls.last.$2.onlyWithSalary, isTrue);
      expect(find.text('Filters (3)'), findsOneWidget);
      await tapChip(t, 'Clear filters');
      expect(repo.calls.last.$2.isActive, isFalse);
      expect(find.text('Filters'), findsOneWidget);
    },
  );

  testWidgets(
    'no jobs under active filters says so and offers to clear them (never "no source")',
    (t) async {
      final repo = CatalogRepo([job('1')], emptyWhenFiltered: true);
      await pumpApp(t, repo: repo);
      await searchFor(t, 'account');
      await t.tap(find.text('Filters'));
      await t.pumpAndSettle();
      await tapChip(t, 'Only with salary');
      expect(find.text('No jobs found'), findsOneWidget);
      expect(
        find.text('No jobs match these filters. Try removing some.'),
        findsOneWidget,
      );
      expect(find.text('No integrated source for this search'), findsNothing);
      await t.tap(find.text('Clear filters').last);
      await t.pumpAndSettle();
      expect(find.text('Account Executive 1'), findsOneWidget);
    },
  );

  testWidgets(
    'an empty catalogue with no filters shows the plain empty state',
    (t) async {
      await pumpApp(t, repo: CatalogRepo(const []));
      await searchFor(t, 'account');
      expect(find.text('No jobs found'), findsOneWidget);
      expect(
        find.text('Try another profession or a broader search.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a server error shows retry; retrying shows the jobs', (t) async {
    final repo = CatalogRepo([job('1')])..failNext = Exception('boom');
    await pumpApp(t, repo: repo);
    await searchFor(t, 'account');
    expect(find.text('Something went wrong'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Account Executive 1'), findsOneWidget);
    expect(repo.calls, hasLength(2));
  });

  testWidgets(
    'detail: description, eligibility, source and the link to the original listing; a link that cannot open says so',
    (t) async {
      final launched = mockLauncher(t, opens: false);
      final repo = CatalogRepo([
        job('7', geo: ['CA', 'US']),
      ]);
      await pumpApp(t, repo: repo);
      await searchFor(t, 'account');
      await t.tap(find.text('Account Executive 7'));
      await t.pumpAndSettle();
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Plain text description of the role.'), findsOneWidget);
      expect(find.text('Open to applicants in: CA, US'), findsOneWidget);
      expect(find.text('Source: Jobicy'), findsOneWidget);
      await t.ensureVisible(find.text('Open original listing'));
      await t.pumpAndSettle();
      await t.tap(find.text('Open original listing'));
      await t.pumpAndSettle();
      expect(launched, [
        'https://jobicy.com/jobs/7',
      ], reason: 'the canonical Jobicy URL, nothing else');
      expect(
        find.text('Could not open the link.'),
        findsOneWidget,
        reason: 'the user is told instead of nothing happening',
      );
    },
  );

  testWidgets('detail: when the link opens there is no error message', (
    t,
  ) async {
    final launched = mockLauncher(t, opens: true);
    await pumpApp(t, repo: CatalogRepo([job('7')]));
    await searchFor(t, 'account');
    await t.tap(find.text('Account Executive 7'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Open original listing'));
    await t.pumpAndSettle();
    await t.tap(find.text('Open original listing'));
    await t.pumpAndSettle();
    expect(launched, hasLength(1));
    expect(find.text('Could not open the link.'), findsNothing);
  });

  testWidgets(
    'favourites: save a catalogue job, find it again after a restart, remove it',
    (t) async {
      final favs = InMemoryFavoritesRepository();
      final repo = CatalogRepo([job('1'), job('2')]);
      await pumpApp(t, repo: repo, favorites: favs);
      await searchFor(t, 'account');
      await t.tap(find.byTooltip('Save job').first);
      await t.pumpAndSettle();
      expect(await favs.list(), hasLength(1));
      final stored = (await favs.list()).single;
      expect((stored.source, stored.externalId), ('jobicy', '1'));
      expect(stored.sourceName, 'Jobicy');

      await pumpApp(
        t,
        repo: repo,
        favorites: favs,
      ); // fresh start: new Cubits read the repository
      await t.tap(find.text('Favorites'));
      await t.pumpAndSettle();
      expect(find.text('Account Executive 1'), findsOneWidget);
      await t.tap(find.byTooltip('Remove from favorites'));
      await t.pumpAndSettle();
      expect(await favs.list(), isEmpty);
    },
  );

  testWidgets(
    'account switch A -> B: B never sees the catalogue jobs A saved; A finds them again',
    (t) async {
      const a = AuthUser(id: 'user-a', email: 'a@example.com');
      const b = AuthUser(id: 'user-b', email: 'b@example.com');
      final auth = FakeAuth()..currentUser = a;
      final favs = PerUserFavorites(auth);
      await pumpApp(
        t,
        repo: CatalogRepo([job('1'), job('2')]),
        auth: auth,
        fakes: Fakes(auth: auth),
        favorites: favs,
      );
      await searchFor(t, 'account');
      await t.tap(find.byTooltip('Save job').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Favorites'));
      await t.pumpAndSettle();
      expect(find.text('Account Executive 1'), findsOneWidget);

      auth.emit(b);
      await t.pumpAndSettle();
      expect(
        find.text('Account Executive 1'),
        findsNothing,
        reason: 'nothing of A is shown to B',
      );
      expect(find.text('No favorites yet'), findsOneWidget);

      auth.emit(a);
      await t.pumpAndSettle();
      expect(
        find.text('Account Executive 1'),
        findsOneWidget,
        reason: 'the favourite of A persisted',
      );
    },
  );

  testWidgets(
    'an active country filter stays visible and removable even when the account does not list that country',
    (t) async {
      final repo = CatalogRepo([job('1')]);
      await pumpApp(t, repo: repo);
      await searchFor(t, 'account');
      final ctx = t.element(find.byType(TextField));
      // as if another account had chosen PT before a switch
      await ctx.read<SearchCubit>().setFilters(
        const JobFilters(countryCode: 'PT'),
      );
      await t.pumpAndSettle();
      expect(find.text('Filters (1)'), findsOneWidget);
      await t.tap(find.text('Filters (1)'));
      await t.pumpAndSettle();
      await tapChip(t, 'PT');
      expect(repo.calls.last.$2.countryCode, isNull);
      expect(find.text('Filters'), findsOneWidget);
    },
  );

  testWidgets(
    'Portuguese: the new controls and the attribution are translated',
    (t) async {
      final repo = CatalogRepo([for (var i = 1; i <= 25; i++) job('$i')]);
      await pumpApp(t, repo: repo, locale: const Locale('pt'));
      await t.tap(find.text('Explorar'));
      await t.pumpAndSettle();
      expect(find.text('Ver vagas recentes'), findsOneWidget);
      await t.ensureVisible(find.text('Ver vagas recentes'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ver vagas recentes'));
      await t.pumpAndSettle();
      expect(find.text('Mostrando 20 vagas'), findsOneWidget);
      expect(find.textContaining('Fonte: Jobicy'), findsWidgets);
      expect(find.text('Filtros'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Mostrar mais'),
        400,
        scrollable: resultsScrollable,
      );
      expect(find.text('Mostrar mais'), findsOneWidget);
    },
  );

  testWidgets('Spanish: the new controls are translated', (t) async {
    await pumpApp(t, repo: CatalogRepo([job('1')]), locale: const Locale('es'));
    await t.tap(find.text('Explorar'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Ver empleos recientes'),
      200,
      scrollable: resultsScrollable,
    );
    expect(find.text('Ver empleos recientes'), findsOneWidget);
    expect(find.text('Filtros'), findsOneWidget);
  });

  testWidgets('narrow, large text, filters open: nothing overflows', (t) async {
    final repo = CatalogRepo([for (var i = 1; i <= 25; i++) job('$i')]);
    await pumpApp(t, repo: repo, size: const Size(320, 568), textScale: 2);
    await searchFor(t, 'account');
    await t.tap(find.text('Filters'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
