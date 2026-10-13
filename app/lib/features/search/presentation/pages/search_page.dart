import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/data/load_status.dart';
import '../../../../core/orbi/orbi.dart';
import '../../../../core/data/data_failure.dart';
import '../../../../core/widgets/data_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../favorites/favorites_cubit.dart';
import '../../../hidden/presentation/hidden_jobs_cubit.dart';
import '../../../jobs/job_actions_menu.dart';
import '../../../preferences/presentation/preferences_cubit.dart';
import '../../../searches/domain/search_spec.dart';
import '../../../searches/presentation/save_search_sheet.dart';
import '../../../searches/presentation/saved_searches_cubit.dart';
import '../../../searches/presentation/saved_searches_page.dart';
import '../../../shell/shell_cubit.dart';
import '../../domain/entities/job_posting.dart';
import '../../domain/job_filters.dart';
import '../cubit/search_cubit.dart';
import '../widgets/area_chips.dart';
import '../widgets/area_picker.dart';
import '../widgets/health_specialty_chips.dart';
import '../widgets/job_detail_view.dart';
import '../widgets/search_filters_panel.dart';
import 'job_detail_page.dart';

/// Explore: a search bar with its filters, a row of quick filters and the results.
/// Compact windows show the results full width and open a job on its own page; from 1024 dp the list and the open job sit side by side;
/// from 1280 dp the filters become a persistent side panel as well.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.onOpenApplication});

  /// Provided only by previews/connectors that can open an application; null hides the button.
  final void Function(JobPosting job)? onOpenApplication;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  ScoredJob? _selected;

  @override
  void initState() {
    super.initState();
    // Explore opens on the newest jobs: nobody should have to type a term (or find a button) to see the catalogue.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = context.read<SearchCubit>();
      if (c.state is SearchIdle) c.browse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String q) {
    setState(() => _selected = null);
    context.read<SearchCubit>().search(q);
  }

  void _apply(JobFilters f) {
    setState(() => _selected = null);
    context.read<SearchCubit>().setFilters(f);
  }

  List<String> _countries() {
    try {
      return context.read<PreferencesCubit>().state.prefs.countriesOfInterest;
    } catch (_) {
      return const [];
    }
  }

  void _openFilters() => showExploreFilters(
    context,
    current: context.read<SearchCubit>().filters,
    countries: _countries(),
    onApply: _apply,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<SearchCubit, SearchState>(
          listener: (context, s) {
            final q = switch (s) {
              SearchLoading(:final query) => query,
              SearchSuccess(:final query) => query,
              SearchEmpty(:final query) => query,
              SearchNoSource(:final query) => query,
              SearchNotConfigured(:final query) => query,
              SearchFailure(:final query) => query,
              SearchIdle() => null,
            };
            if (q != null && _controller.text != q) _controller.text = q;
          },
        ),
        BlocListener<ShellCubit, ShellState>(
          listenWhen: (a, b) => a.searchFocusTick != b.searchFocusTick,
          // The page is still offstage in this frame (IndexedStack), so ask for focus once it is visible.
          listener: (context, s) =>
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => mounted ? _focus.requestFocus() : null,
              ),
        ),
        BlocListener<ShellCubit, ShellState>(
          listenWhen: (a, b) => a.filtersTick != b.filtersTick,
          listener: (context, s) =>
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => mounted && MediaQuery.sizeOf(context).width < 1280
                    ? _openFilters()
                    : null,
              ),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, box) {
          final split = WindowClass.of(box.maxWidth) == WindowClass.expanded;
          final sidebar = box.maxWidth >= 1280;
          final header = BlocBuilder<SearchCubit, SearchState>(
            buildWhen: (a, b) => a.filters != b.filters,
            builder: (context, s) => _Header(
              controller: _controller,
              focus: _focus,
              filters: s.filters,
              showFiltersButton: !sidebar,
              onSubmit: _submit,
              onClear: () => context.read<SearchCubit>().browse(),
              onFilters: _openFilters,
              onChanged: _apply,
            ),
          );
          final results = BlocBuilder<SearchCubit, SearchState>(
            builder: (context, s) => _Results(
              state: s,
              selected: _selected,
              split: split,
              onSelect: _select,
              onSearch: _submit,
              onOpenApplication: widget.onOpenApplication,
            ),
          );
          final list = Column(
            children: [
              header,
              Expanded(child: results),
            ],
          );
          if (!split) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: list,
              ),
            );
          }
          return Row(
            children: [
              if (sidebar)
                BlocBuilder<SearchCubit, SearchState>(
                  buildWhen: (a, b) => a.filters != b.filters,
                  builder: (context, s) => FilterSidebar(
                    filters: s.filters,
                    countries: _countries(),
                    onChanged: _apply,
                  ),
                ),
              SizedBox(width: AppSize.listPaneWidth, child: list),
              VerticalDivider(width: 1, color: context.colors.hairline),
              Expanded(
                child: _selected == null
                    ? OrbiEmptyState(
                        icon: Icons.ads_click,
                        title: l.jobDetailTitle,
                        body: l.selectJobHint,
                      )
                    : JobDetailView(
                        scored: _selected!,
                        onOpenApplication: widget.onOpenApplication == null
                            ? null
                            : () => widget.onOpenApplication!(_selected!.job),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _select(ScoredJob s, bool split) {
    if (split) {
      setState(() => _selected = s);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => JobDetailPage(
            scored: s,
            onOpenApplication: widget.onOpenApplication == null
                ? null
                : () => widget.onOpenApplication!(s.job),
          ),
        ),
      );
    }
  }
}

/// The search bar (with the filters button and its badge) and the row of quick filters.
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.focus,
    required this.filters,
    required this.showFiltersButton,
    required this.onSubmit,
    required this.onClear,
    required this.onFilters,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final JobFilters filters;
  final bool showFiltersButton;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;
  final VoidCallback onFilters;
  final ValueChanged<JobFilters> onChanged;

  String _areaChipLabel(AppLocalizations l) {
    final a = filters.area;
    if (a == null) return l.filterAreaChip;
    final sp = filters.specialty;
    return sp == null
        ? areaLabel(a, l)
        : '${areaLabel(a, l)} · ${specialtyLabel(sp, l)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void toggleMode(WorkMode m, bool on) => onChanged(
      filters.copyWith(
        workModes: on
            ? {...filters.workModes, m}
            : ({...filters.workModes}..remove(m)),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s3,
            AppSpace.s4,
            AppSpace.s1,
          ),
          child: OrbiSearchField(
            controller: controller,
            focusNode: focus,
            onSubmitted: onSubmit,
            onChanged: (v) {
              if (v.isEmpty) onClear();
            },
            trailing: showFiltersButton
                ? FiltersButton(
                    count: activeFilterCount(filters),
                    onPressed: onFilters,
                  )
                : null,
          ),
        ),
        OrbiChipRow(
          children: [
            OrbiFilterChip(
              label: l.ssMine,
              icon: Icons.bookmarks_outlined,
              selected: false,
              onSelected: (_) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedSearchesPage(),
                ),
              ),
            ),
            OrbiFilterChip(
              label: _areaChipLabel(l),
              icon: filters.area == null ? Icons.category_outlined : null,
              selected: filters.area != null,
              trailing: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: filters.area != null
                    ? context.colors.chipSelectedFg
                    : context.colors.muted,
              ),
              onSelected: (_) async {
                final picked = await showAreaPicker(
                  context,
                  area: filters.area,
                  specialty: filters.specialty,
                );
                if (picked == null) return;
                onChanged(
                  filters.copyWith(
                    area: picked.area,
                    clearArea: picked.area == null,
                    specialty: picked.specialty,
                    clearSpecialty: picked.specialty == null,
                  ),
                );
              },
            ),
            OrbiFilterChip(
              label: l.workModeRemote,
              selected: filters.workModes.contains(WorkMode.remote),
              onSelected: (on) => toggleMode(WorkMode.remote, on),
            ),
            OrbiFilterChip(
              label: l.workModeHybrid,
              selected: filters.workModes.contains(WorkMode.hybrid),
              onSelected: (on) => toggleMode(WorkMode.hybrid, on),
            ),
            OrbiFilterChip(
              label: l.workModeOnsite,
              selected: filters.workModes.contains(WorkMode.onsite),
              onSelected: (on) => toggleMode(WorkMode.onsite, on),
            ),
            OrbiFilterChip(
              label: l.filterPublished7,
              selected: filters.publishedWithinDays == 7,
              onSelected: (on) => onChanged(
                on
                    ? filters.copyWith(publishedWithinDays: 7)
                    : filters.copyWith(clearPublished: true),
              ),
            ),
            OrbiFilterChip(
              label: l.filterWithSalary,
              selected: filters.onlyWithSalary,
              onSelected: (on) =>
                  onChanged(filters.copyWith(onlyWithSalary: on)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.state,
    required this.selected,
    required this.split,
    required this.onSelect,
    required this.onSearch,
    required this.onOpenApplication,
  });

  final SearchState state;
  final ScoredJob? selected;
  final bool split;
  final void Function(ScoredJob, bool) onSelect;
  final ValueChanged<String> onSearch;
  final void Function(JobPosting)? onOpenApplication;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final spec = context.read<SearchCubit>().currentSpec;
    return switch (state) {
      SearchIdle() => ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          const SizedBox(height: AppSpace.s6),
          OrbiEmptyState(
            icon: Icons.travel_explore,
            title: l.exploreIdleTitle,
            body: l.exploreIdleBody,
            kind: OrbiStateKind.info,
          ),
          const SizedBox(height: AppSpace.s4),
          Center(
            child: OrbiSecondaryButton(
              label: l.browseLatest,
              icon: Icons.list_alt,
              onPressed: () => context.read<SearchCubit>().browse(),
            ),
          ),
        ],
      ),
      SearchLoading() => const Padding(
        padding: EdgeInsets.all(AppSpace.s4),
        child: OrbiSkeletonList(),
      ),
      SearchNotConfigured() => OrbiEmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.notConfiguredTitle,
        body: l.notConfiguredBody,
        kind: OrbiStateKind.info,
      ),
      SearchNoSource() => OrbiEmptyState(
        icon: Icons.public_off,
        title: l.noSourceTitle,
        body: l.noSourceBody,
        kind: OrbiStateKind.info,
      ),
      SearchEmpty(:final filters) => OrbiEmptyState(
        icon: Icons.search_off,
        title: l.emptyTitle,
        body: filters.specialty != null
            ? l.specialtyEmpty
            : filters.isActive
            ? l.emptyFiltersBody
            : l.emptyBody,
        action: filters.specialty != null
            ? OrbiSecondaryButton(
                label: l.portalsButton,
                icon: Icons.open_in_new,
                onPressed: () =>
                    showSpecialtyPortals(context, filters.specialty),
              )
            : filters.isActive
            ? OrbiSecondaryButton(
                label: l.filtersClear,
                icon: Icons.filter_alt_off_outlined,
                onPressed: () => context.read<SearchCubit>().clearFilters(),
              )
            : null,
        secondaryAction: _SaveSearchButton(
          spec: context.read<SearchCubit>().currentSpec,
          prominent: true,
        ),
      ),
      SearchFailure() => OrbiEmptyState(
        icon: Icons.error_outline,
        title: l.errorTitle,
        body: l.errorBody,
        kind: OrbiStateKind.error,
        action: OrbiSecondaryButton(
          label: l.retry,
          icon: Icons.refresh,
          onPressed: () => context.read<SearchCubit>().retry(),
        ),
      ),
      SearchSuccess(
        :final jobs,
        :final hasMore,
        :final loadingMore,
        :final loadMoreFailed,
      ) =>
        BlocConsumer<FavoritesCubit, FavoritesState>(
          listenWhen: (a, b) => a.actionTick != b.actionTick,
          listener: (context, f) {
            if (f.actionFailure != null) {
              showDataFailure(context, f.actionFailure!);
            }
          },
          builder: (context, favs) => BlocBuilder<HiddenJobsCubit, HiddenJobsState>(
            builder: (context, hiddenState) {
              final shownJobs = [
                for (final j in jobs)
                  if (!hiddenState.isHidden(j.job)) j,
              ];
              final hiddenHere = jobs.length - shownJobs.length;
              if (shownJobs.isEmpty &&
                  hasMore &&
                  !loadingMore &&
                  !loadMoreFailed) {
                // a whole page was hidden: fetch the next one instead of showing an empty list
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => context.mounted
                      ? context.read<SearchCubit>().loadMore()
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpace.s4),
                itemCount:
                    shownJobs.length + 1 + (hasMore || loadMoreFailed ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    // A Wrap, not a Row: with large text the save button drops under the count instead of overflowing.
                    return Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            // With more pages behind it the count is "shown so far", never a catalogue total.
                            '${hasMore ? l.resultsShown(shownJobs.length) : l.resultsCount(shownJobs.length)} · ${l.sortNewest}${hiddenHere > 0 ? ' · ${l.hdCount(hiddenHere)}' : ''}',
                            style: context.metadataStyle,
                          ),
                        ),
                        _SaveSearchButton(spec: spec),
                      ],
                    );
                  }
                  if (i == shownJobs.length + 1) {
                    return _LoadMoreFooter(
                      loading: loadingMore,
                      failed: loadMoreFailed,
                      onLoadMore: () => context.read<SearchCubit>().loadMore(),
                    );
                  }
                  final s = shownJobs[i - 1];
                  return OrbiJobCard(
                    scored: s,
                    menu: JobActionsMenu(job: s.job),
                    selected: split && selected?.job == s.job,
                    isFavorite: favs.items.containsKey(
                      FavoritesCubit.keyOf(s.job),
                    ),
                    onFavoriteChanged: (_) =>
                        context.read<FavoritesCubit>().toggle(s),
                    onTap: () => onSelect(s, split),
                  );
                },
              );
            },
          ),
        ),
    };
  }
}

/// Saves what Explore shows (text, country and every filter) in the account, optionally with alerts; when it is already saved, opens it for editing.
/// Recent searches are separate and stay on the device.
class _SaveSearchButton extends StatelessWidget {
  const _SaveSearchButton({required this.spec, this.prominent = false});

  /// What Explore shows; passed in (not read here) so the button follows every new search.
  final SearchSpec spec;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocConsumer<SavedSearchesCubit, SavedSearchesState>(
      listenWhen: (a, b) => a.actionTick != b.actionTick,
      listener: (context, s) {
        if (s.actionFailure != null) showDataFailure(context, s.actionFailure!);
      },
      builder: (context, s) {
        if (spec.isEmpty) return const SizedBox.shrink();
        final saved = context.read<SavedSearchesCubit>().savedFor(spec);
        final signedOut =
            s.status == LoadStatus.failure &&
            needsSignIn(s.failure ?? DataFailureKind.unknown);
        final label = saved == null ? l.ssSaveAction : l.ssEdit;
        final icon = saved == null
            ? Icons.bookmark_add_outlined
            : (saved.alertsEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.bookmark_rounded);
        Future<void> onTap() async {
          if (signedOut) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SavedSearchesPage(),
              ),
            );
            return;
          }
          await showSaveSearchSheet(context, spec: spec, editing: saved);
        }

        return prominent
            ? OrbiSecondaryButton(
                label: l.ssSaveAction,
                icon: icon,
                onPressed: s.busy ? null : onTap,
              )
            : OrbiTextButton(
                label: label,
                icon: icon,
                onPressed: s.busy ? null : onTap,
              );
      },
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.loading,
    required this.failed,
    required this.onLoadMore,
  });
  final bool loading;
  final bool failed;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Column(
        children: [
          if (failed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s2),
              child: Text(
                l.loadMoreFailed,
                style: context.text.bodyMedium!.copyWith(
                  color: context.colors.muted,
                ),
              ),
            ),
          OrbiSecondaryButton(
            label: failed ? l.retry : l.loadMore,
            icon: failed ? Icons.refresh : Icons.expand_more,
            loading: loading,
            onPressed: loading ? null : onLoadMore,
          ),
        ],
      ),
    );
  }
}
