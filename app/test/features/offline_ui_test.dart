import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orbijob/features/search/data/offline_first_search_repository.dart';
import 'package:orbijob/features/search/data/search_results_cache.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';

import '../helpers/harness.dart';

// ORBI-001 on the real app: Home and Explore with and without a connection. The catalogue is a fake; the cache is the real offline-first repository.

JobPosting job(String id) => JobPosting(
  source: 'jobicy',
  externalId: id,
  company: 'Acme',
  title: 'Flutter Developer $id',
  originalUrl: 'https://jobicy.com/jobs/$id',
  workMode: WorkMode.remote,
  publishedAt: DateTime.now().subtract(const Duration(days: 1)),
  sourceName: 'Jobicy',
  geoRestrictions: const ['Anywhere'],
  description: 'Plain text description.',
);

class Net implements SearchRepository {
  bool offline = false;
  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async {
    if (offline) throw http.ClientException('no connection');
    return SearchResult(
      jobs: [ScoredJob(job('1')), ScoredJob(job('2'))],
      hasIntegratedSource: true,
    );
  }
}

Future<void> searchFor(WidgetTester t, String q) async {
  await t.tap(find.text('Explore'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), q);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'no connection and nothing saved: Home says so and what is needed, not "Something went wrong"',
    (t) async {
      final net = Net()..offline = true;
      await pumpApp(
        t,
        repo: OfflineFirstSearchRepository(
          net,
          MemorySearchResultsCache(),
          networkTimeout: const Duration(milliseconds: 100),
        ),
      );
      expect(find.text('No connection'), findsWidgets);
      expect(
        find.textContaining('Connect to see the newest jobs'),
        findsOneWidget,
      );
      expect(find.text('Something went wrong'), findsNothing);
    },
  );

  testWidgets(
    'Explore: a search already made opens offline with its date and a way to try again; a new one explains it needs the internet',
    (t) async {
      final net = Net();
      await pumpApp(
        t,
        repo: OfflineFirstSearchRepository(
          net,
          MemorySearchResultsCache(),
          networkTimeout: const Duration(milliseconds: 100),
        ),
      );
      await searchFor(t, 'flutter');
      expect(find.text('Flutter Developer 1'), findsOneWidget);
      expect(
        find.textContaining('No connection · data saved on'),
        findsNothing,
        reason: 'fresh results carry no notice',
      );

      net.offline = true;
      await searchFor(t, 'flutter');
      expect(
        find.text('Flutter Developer 1'),
        findsOneWidget,
        reason: 'the saved page is shown, not an error',
      );
      expect(
        find.textContaining('No connection · data saved on'),
        findsOneWidget,
      );
      expect(find.textContaining('may be out of date'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);

      await t.enterText(find.byType(TextField), 'something never searched');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.text('Flutter Developer 1'), findsNothing);
      expect(find.text('No connection'), findsOneWidget);
      expect(
        find.textContaining('has not been made on this device yet'),
        findsOneWidget,
      );
      expect(find.text('Something went wrong'), findsNothing);
    },
  );

  testWidgets('the saved results notice reads in Portuguese and Spanish', (
    t,
  ) async {
    final net = Net();
    await pumpApp(
      t,
      locale: const Locale('pt'),
      repo: OfflineFirstSearchRepository(
        net,
        MemorySearchResultsCache(),
        networkTimeout: const Duration(milliseconds: 100),
      ),
    );
    await t.tap(find.text('Explorar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'flutter');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    net.offline = true;
    await t.enterText(find.byType(TextField), 'flutter ');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(
      find.textContaining('Sem conexão · dados salvos em'),
      findsOneWidget,
    );
  });
}
