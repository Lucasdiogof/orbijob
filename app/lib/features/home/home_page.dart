import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/load_status.dart';
import '../../core/design/design.dart';
import '../../core/widgets/app_filter_chip.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';
import '../applications/applications_cubit.dart';
import '../preferences/presentation/preferences_cubit.dart';
import '../favorites/favorites_cubit.dart';
import '../preferences/presentation/saved_searches_cubit.dart';

import '../search/presentation/pages/job_detail_page.dart';
import '../search/presentation/widgets/area_chips.dart';
import '../search/presentation/widgets/job_card.dart';
import 'latest_jobs_cubit.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/state_view.dart';
import '../search/presentation/cubit/areas_cubit.dart';
import '../search/presentation/cubit/search_cubit.dart';
import '../shell/shell_cubit.dart';
import 'recent_searches_cubit.dart';

/// Home: a way into search plus honest empty panels for what needs a profile and connected sources.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final panels = [
      _InfoPanel(
        icon: Icons.auto_awesome_outlined,
        title: l.homeForYouEmptyTitle,
        body: l.homeForYouEmptyBody,
      ),
      BlocBuilder<PreferencesCubit, PreferencesState>(
        builder: (context, p) {
          final countries = p.prefs.countriesOfInterest;
          final has = p.synced && countries.isNotEmpty;
          return _InfoPanel(
            icon: Icons.public,
            title: has ? l.countriesTitle : l.interestCountriesEmptyTitle,
            body: has ? countries.join(', ') : l.interestCountriesEmptyBody,
          );
        },
      ),
      BlocBuilder<ApplicationsCubit, ApplicationsState>(
        builder: (context, a) {
          final has = a.status == LoadStatus.ready && a.items.isNotEmpty;
          return _InfoPanel(
            icon: Icons.assignment_outlined,
            title: has ? l.applicationsTitle : l.homeApplicationsEmptyTitle,
            body: has
                ? l.homeApplicationsCount(a.items.length)
                : l.homeApplicationsEmptyBody,
          );
        },
      ),
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
        child: ListView(
          padding: EdgeInsets.all(wide ? AppSpace.s6 : AppSpace.s4),
          children: [
            Semantics(
              header: true,
              child: Text(l.homeTitle, style: context.text.headlineMedium),
            ),
            const SizedBox(height: AppSpace.s4),
            AppSearchField(
              hint: l.homeSearchHint,
              readOnly: true,
              onTap: context.read<ShellCubit>().openSearch,
            ),
            const SizedBox(height: AppSpace.s6),
            BlocBuilder<RecentSearchesCubit, List<String>>(
              builder: (context, recent) => recent.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: l.recentSearchesTitle,
                            action: TextButton(
                              onPressed: context
                                  .read<RecentSearchesCubit>()
                                  .clear,
                              child: Text(l.recentSearchesClear),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s3),
                          Wrap(
                            spacing: AppSpace.s2,
                            runSpacing: AppSpace.s1,
                            children: [
                              for (final q in recent)
                                AppFilterChip(
                                  label: q,
                                  icon: Icons.history,
                                  selected: false,
                                  onSelected: (_) {
                                    context.read<SearchCubit>().search(q);
                                    context.read<ShellCubit>().goTo(
                                      ShellCubit.explore,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
              builder: (context, saved) => saved.items.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(title: l.savedSearchesTitle),
                          const SizedBox(height: AppSpace.s3),
                          Wrap(
                            spacing: AppSpace.s2,
                            runSpacing: AppSpace.s1,
                            children: [
                              for (final q in saved.items)
                                AppFilterChip(
                                  label: SavedSearchesCubit.termOf(q),
                                  icon: Icons.bookmark_border,
                                  selected: false,
                                  onSelected: (_) {
                                    context.read<SearchCubit>().search(
                                      SavedSearchesCubit.termOf(q),
                                    );
                                    context.read<ShellCubit>().goTo(
                                      ShellCubit.explore,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            BlocBuilder<AreasCubit, AreasState>(
              builder: (context, a) => a.available.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(title: l.homeAreasTitle),
                          const SizedBox(height: AppSpace.s3),
                          AreaChips(
                            onSelected: (area) {
                              final search = context.read<SearchCubit>();
                              search.setFilters(search.filters.copyWith(area: area, clearArea: area == null));
                              context.read<ShellCubit>().goTo(ShellCubit.explore);
                            },
                          ),
                        ],
                      ),
                    ),
            ),
            const _LatestJobs(),
            const SizedBox(height: AppSpace.s6),
            SectionHeader(title: l.homeForYouTitle),
            const SizedBox(height: AppSpace.s3),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in panels)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpace.s3),
                        child: p,
                      ),
                    ),
                ],
              )
            else
              for (final p in panels) ...[
                p,
                const SizedBox(height: AppSpace.s3),
              ],
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: c.primary),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    body,
                    style: context.text.bodyMedium!.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The newest jobs of the catalogue, straight on Home: the app opens on real jobs, not on an empty screen.
class _LatestJobs extends StatelessWidget {
  const _LatestJobs();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<LatestJobsCubit, LatestJobsState>(
      builder: (context, s) {
        final header = SectionHeader(
          title: l.homeLatestTitle,
          action: s.status == LatestStatus.ready
              ? TextButton(
                  onPressed: () {
                    context.read<SearchCubit>().browse();
                    context.read<ShellCubit>().goTo(ShellCubit.explore);
                  },
                  child: Text(l.homeLatestSeeAll),
                )
              : null,
        );
        final body = switch (s.status) {
          LatestStatus.loading => const SizedBox(height: 280, child: SkeletonList()),
          LatestStatus.notConfigured => StateView(
            icon: Icons.cloud_off_outlined,
            title: l.notConfiguredTitle,
            body: l.notConfiguredBody,
            kind: StateKind.info,
          ),
          LatestStatus.empty => StateView(icon: Icons.work_off_outlined, title: l.homeLatestEmpty),
          LatestStatus.failure => StateView(
            icon: Icons.error_outline,
            title: l.errorTitle,
            body: l.errorBody,
            kind: StateKind.error,
            action: AppButton(
              label: l.retry,
              icon: Icons.refresh,
              onPressed: () => context.read<LatestJobsCubit>().load(),
            ),
          ),
          LatestStatus.ready => BlocBuilder<FavoritesCubit, FavoritesState>(
            builder: (context, favs) => Column(
              children: [
                for (final j in s.jobs) ...[
                  JobCard(
                    scored: j,
                    isFavorite: favs.items.containsKey(FavoritesCubit.keyOf(j.job)),
                    onFavoriteChanged: (_) => context.read<FavoritesCubit>().toggle(j),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => JobDetailPage(scored: j)),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s3),
                ],
              ],
            ),
          ),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, const SizedBox(height: AppSpace.s3), body],
        );
      },
    );
  }
}
