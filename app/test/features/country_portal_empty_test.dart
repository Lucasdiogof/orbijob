import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/orbi/orbi.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/features/search/presentation/cubit/search_cubit.dart';
import 'package:orbijob/l10n/app_localizations.dart';

import '../helpers/harness.dart';

class _Empty implements SearchRepository {
  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async => const SearchResult(jobs: [], hasIntegratedSource: true);
}

void main() {
  testWidgets(
    'a country the catalogue has nothing for points to its official employment service,',
    (t) async {
      await pumpApp(t, repo: _Empty());
      final l = AppLocalizations.of(t.element(find.byType(Scaffold).first));
      await t.tap(find.text(l.navExplore).first);
      await t.pumpAndSettle();
      final cubit = BlocProvider.of<SearchCubit>(
        t.element(find.byType(Scaffold).first),
      );
      await cubit.search('x');
      await cubit.setFilters(const JobFilters(countryCode: 'BR'));
      await t.pumpAndSettle();
      expect(
        find.widgetWithText(OrbiSecondaryButton, l.officialPortalButton),
        findsOneWidget,
      );
      expect(find.textContaining('Brazil'), findsWidgets);
    },
  );
}
