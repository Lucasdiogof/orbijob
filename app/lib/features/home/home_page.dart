import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/load_status.dart';
import '../../core/design/design.dart';
import '../../core/orbi/orbi.dart';
import '../../l10n/app_localizations.dart';
import '../applications/applications_cubit.dart';
import '../favorites/favorites_cubit.dart';
import '../preferences/presentation/saved_searches_cubit.dart';
import '../search/domain/continent.dart';
import '../search/domain/entities/job_posting.dart';
import '../search/domain/job_area.dart';
import '../search/domain/job_filters.dart';
import '../search/presentation/cubit/areas_cubit.dart';
import '../search/presentation/cubit/search_cubit.dart';
import '../search/presentation/pages/job_detail_page.dart';
import '../search/presentation/widgets/area_grid.dart';
import '../search/presentation/widgets/search_filters_panel.dart'
    show continentLabel;
import '../shell/shell_cubit.dart';
import 'latest_jobs_cubit.dart';
import 'recent_searches_cubit.dart';

/// Home: a dashboard of opportunities. Brand-first header with a discreet greeting, the global search with a filters shortcut, quick filters,
/// the newest jobs, areas as tiles with real counts, regions, remote jobs and, when signed in with processes under way, where you left off.
/// Every number on this screen is read from the catalogue; nothing is invented.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _goExplore(BuildContext context, JobFilters Function(JobFilters) f) {
    final search = context.read<SearchCubit>();
    search.setFilters(f(search.filters));
    context.read<ShellCubit>().goTo(ShellCubit.explore);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l.homeGreetingMorning
        : hour < 18
        ? l.homeGreetingAfternoon
        : l.homeGreetingEvening;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            wide ? AppSpace.s6 : AppSpace.s4,
            wide ? AppSpace.s6 : AppSpace.s2,
            wide ? AppSpace.s6 : AppSpace.s4,
            AppSpace.s8,
          ),
          children: [
            Text(greeting, style: context.metadataStyle),
            const SizedBox(height: AppSpace.s1),
            Semantics(
              header: true,
              child: Text(l.homeHeadline, style: context.text.displayLarge),
            ),
            const SizedBox(height: AppSpace.s4),
            OrbiSearchField(
              hint: l.homeSearchHint,
              readOnly: true,
              onTap: context.read<ShellCubit>().openSearch,
              trailing: IconButton(
                tooltip: l.exploreOpenFilters,
                icon: const Icon(Icons.tune_rounded),
                onPressed: context.read<ShellCubit>().openFilters,
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            _QuickFilters(onGo: (f) => _goExplore(context, f)),
            const SizedBox(height: AppSpace.s6),
            const _ContinueSection(),
            const _LatestJobs(),
            const SizedBox(height: AppSpace.s6),
            const _AreasSection(),
            const _RegionsSection(),
            const _RemoteJobs(),
          ],
        ),
      ),
    );
  }
}

class _QuickFilters extends StatelessWidget {
  const _QuickFilters({required this.onGo});
  final void Function(JobFilters Function(JobFilters)) onGo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OrbiChipRow(
      padding: EdgeInsets.zero,
      children: [
        OrbiFilterChip(
          label: l.workModeRemote,
          icon: Icons.public,
          selected: false,
          onSelected: (_) => onGo(
            (f) => f.copyWith(workModes: {...f.workModes, WorkMode.remote}),
          ),
        ),
        OrbiFilterChip(
          label: l.workModeHybrid,
          icon: Icons.sync_alt,
          selected: false,
          onSelected: (_) => onGo(
            (f) => f.copyWith(workModes: {...f.workModes, WorkMode.hybrid}),
          ),
        ),
        OrbiFilterChip(
          label: l.workModeOnsite,
          icon: Icons.apartment,
          selected: false,
          onSelected: (_) => onGo(
            (f) => f.copyWith(workModes: {...f.workModes, WorkMode.onsite}),
          ),
        ),
        OrbiFilterChip(
          label: l.homeQuickLast7,
          icon: Icons.schedule,
          selected: false,
          onSelected: (_) => onGo((f) => f.copyWith(publishedWithinDays: 7)),
        ),
      ],
    );
  }
}

/// Where you left off: recent searches and saved searches as one quiet row, and a summary of the applications under way.
class _ContinueSection extends StatelessWidget {
  const _ContinueSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<RecentSearchesCubit, List<String>>(
      builder: (context, recent) =>
          BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
            builder: (context, saved) =>
                BlocBuilder<ApplicationsCubit, ApplicationsState>(
                  builder: (context, apps) {
                    final terms = <(String, bool)>[
                      for (final q in saved.items)
                        (SavedSearchesCubit.termOf(q), true),
                      for (final q in recent) (q, false),
                    ];
                    final seen = <String>{};
                    final unique = [
                      for (final t in terms)
                        if (seen.add(t.$1.toLowerCase())) t,
                    ].take(8).toList();
                    final hasApps =
                        apps.status == LoadStatus.ready &&
                        apps.items.isNotEmpty;
                    if (unique.isEmpty && !hasApps) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OrbiSectionHeader(
                            title: l.homeContinueTitle,
                            actionLabel: unique.isNotEmpty && recent.isNotEmpty
                                ? l.recentSearchesClear
                                : null,
                            onAction: context.read<RecentSearchesCubit>().clear,
                          ),
                          const SizedBox(height: AppSpace.s2),
                          if (hasApps)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpace.s2,
                              ),
                              child: OrbiCard(
                                onTap: () => context.read<ShellCubit>().goTo(
                                  ShellCubit.applications,
                                ),
                                padding: const EdgeInsets.all(AppSpace.s3),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.assignment_turned_in_outlined,
                                      color: context.colors.primary,
                                    ),
                                    const SizedBox(width: AppSpace.s3),
                                    Expanded(
                                      child: Text(
                                        l.homeApplicationsCount(
                                          apps.items.length,
                                        ),
                                        style: context.text.labelLarge,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: context.colors.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (unique.isNotEmpty)
                            OrbiChipRow(
                              padding: EdgeInsets.zero,
                              children: [
                                for (final (q, isSaved) in unique)
                                  OrbiFilterChip(
                                    label: q,
                                    icon: isSaved
                                        ? Icons.bookmark_border
                                        : Icons.history,
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
                    );
                  },
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
      builder: (context, s) => _JobsSection(
        title: l.homeLatestTitle,
        state: s,
        onRetry: () => context.read<LatestJobsCubit>().load(),
        onSeeAll: () {
          context.read<SearchCubit>().browse();
          context.read<ShellCubit>().goTo(ShellCubit.explore);
        },
      ),
    );
  }
}

class _RemoteJobs extends StatelessWidget {
  const _RemoteJobs();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<RemoteJobsCubit, LatestJobsState>(
      builder: (context, s) {
        // Nothing to say when there are no remote jobs: the section simply is not there.
        if (s.status == LatestStatus.empty ||
            s.status == LatestStatus.notConfigured) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.s6),
          child: _JobsSection(
            title: l.homeRemoteTitle,
            state: s,
            onRetry: () => context.read<RemoteJobsCubit>().load(),
            onSeeAll: () {
              final search = context.read<SearchCubit>();
              search.setFilters(
                search.filters.copyWith(workModes: {WorkMode.remote}),
              );
              context.read<ShellCubit>().goTo(ShellCubit.explore);
            },
            maxItems: 3,
          ),
        );
      },
    );
  }
}

class _JobsSection extends StatelessWidget {
  const _JobsSection({
    required this.title,
    required this.state,
    required this.onRetry,
    required this.onSeeAll,
    this.maxItems = 5,
  });

  final String title;
  final LatestJobsState state;
  final VoidCallback onRetry;
  final VoidCallback onSeeAll;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = switch (state.status) {
      LatestStatus.loading => const SizedBox(
        height: 260,
        child: OrbiSkeletonList(count: 2),
      ),
      LatestStatus.notConfigured => OrbiEmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.notConfiguredTitle,
        body: l.notConfiguredBody,
        kind: OrbiStateKind.info,
      ),
      LatestStatus.empty => OrbiEmptyState(
        icon: Icons.work_off_outlined,
        title: l.homeLatestEmpty,
      ),
      LatestStatus.failure => OrbiEmptyState(
        icon: Icons.error_outline,
        title: l.errorTitle,
        body: l.errorBody,
        kind: OrbiStateKind.error,
        action: OrbiSecondaryButton(
          label: l.retry,
          icon: Icons.refresh,
          onPressed: onRetry,
        ),
      ),
      LatestStatus.ready => BlocBuilder<FavoritesCubit, FavoritesState>(
        builder: (context, favs) => OrbiAdaptiveGrid(
          children: [
            for (final j in state.jobs.take(maxItems))
              OrbiJobCard(
                scored: j,
                compact: true,
                isFavorite: favs.items.containsKey(FavoritesCubit.keyOf(j.job)),
                onFavoriteChanged: (_) =>
                    context.read<FavoritesCubit>().toggle(j),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => JobDetailPage(scored: j),
                  ),
                ),
              ),
          ],
        ),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrbiSectionHeader(
          title: title,
          actionLabel: state.status == LatestStatus.ready
              ? l.homeLatestSeeAll
              : null,
          onAction: onSeeAll,
        ),
        const SizedBox(height: AppSpace.s3),
        body,
      ],
    );
  }
}

class _AreasSection extends StatelessWidget {
  const _AreasSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<AreasCubit, AreasState>(
      builder: (context, a) {
        if (a.available.isEmpty) return const SizedBox.shrink();
        void pick(JobArea area) {
          final search = context.read<SearchCubit>();
          search.setFilters(search.filters.copyWith(area: area));
          context.read<ShellCubit>().goTo(ShellCubit.explore);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrbiSectionHeader(
                title: l.homeAreasTitle,
                actionLabel: a.available.length > 6 ? l.areaAll : null,
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AllAreasPage(onSelected: pick),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              AreaGrid(maxItems: 6, onSelected: pick),
            ],
          ),
        );
      },
    );
  }
}

class _RegionsSection extends StatelessWidget {
  const _RegionsSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrbiSectionHeader(title: l.homeRegionsTitle),
        const SizedBox(height: AppSpace.s2),
        OrbiChipRow(
          padding: EdgeInsets.zero,
          children: [
            for (final k in Continent.values)
              OrbiFilterChip(
                label: continentLabel(k, l),
                icon: Icons.public,
                selected: false,
                onSelected: (_) {
                  final search = context.read<SearchCubit>();
                  search.setFilters(search.filters.copyWith(continent: k));
                  context.read<ShellCubit>().goTo(ShellCubit.explore);
                },
              ),
          ],
        ),
      ],
    );
  }
}
