import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../favorites/favorites_cubit.dart';
import '../../../home/home_page.dart';
import '../../../shell/shell_cubit.dart';
import '../../domain/entities/job_posting.dart';
import '../cubit/search_cubit.dart';
import '../widgets/job_card.dart';
import '../widgets/job_detail_view.dart';
import 'job_detail_page.dart';

/// Explore: search field + results. Expanded windows (>= 1024) show list and detail side by side.
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
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String q) {
    setState(() => _selected = null);
    context.read<SearchCubit>().search(q);
  }

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
      ],
      child: LayoutBuilder(
        builder: (context, box) {
          final split = WindowClass.of(box.maxWidth) == WindowClass.expanded;
          final field = Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s4,
              AppSpace.s4,
              AppSpace.s2,
            ),
            child: _SearchField(
              controller: _controller,
              focus: _focus,
              onSubmit: _submit,
              onClear: () => context.read<SearchCubit>().clear(),
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
          if (!split) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    field,
                    Expanded(child: results),
                  ],
                ),
              ),
            );
          }
          return Row(
            children: [
              SizedBox(
                width: AppSize.listPaneWidth,
                child: Column(
                  children: [
                    field,
                    Expanded(child: results),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: context.colors.divider),
              Expanded(
                child: _selected == null
                    ? StateView(
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.onSubmit,
    required this.onClear,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      controller: controller,
      focusNode: focus,
      onSubmitted: onSubmit,
      onChanged: (v) {
        if (v.isEmpty) onClear();
      },
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
    return switch (state) {
      SearchIdle() => ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          const SizedBox(height: AppSpace.s6),
          StateView(
            icon: Icons.travel_explore,
            title: l.exploreIdleTitle,
            body: l.exploreIdleBody,
            kind: StateKind.info,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s1,
            children: [
              for (final (label, icon) in HomePage.areas(l))
                AppFilterChip(
                  label: label,
                  icon: icon,
                  selected: false,
                  onSelected: (_) => onSearch(label),
                ),
            ],
          ),
        ],
      ),
      SearchLoading() => const Padding(
        padding: EdgeInsets.all(AppSpace.s4),
        child: SkeletonList(),
      ),
      SearchNoSource() => StateView(
        icon: Icons.public_off,
        title: l.noSourceTitle,
        body: l.noSourceBody,
        kind: StateKind.info,
      ),
      SearchEmpty() => StateView(
        icon: Icons.search_off,
        title: l.emptyTitle,
        body: l.emptyBody,
      ),
      SearchFailure(:final query) => StateView(
        icon: Icons.error_outline,
        title: l.errorTitle,
        body: l.errorBody,
        kind: StateKind.error,
        action: AppButton(
          label: l.retry,
          icon: Icons.refresh,
          onPressed: () => onSearch(query),
        ),
      ),
      SearchSuccess(:final jobs) =>
        BlocBuilder<FavoritesCubit, Map<String, ScoredJob>>(
          builder: (context, favs) => ListView.separated(
            padding: const EdgeInsets.all(AppSpace.s4),
            itemCount: jobs.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Semantics(
                  liveRegion: true,
                  child: Text(
                    l.resultsCount(jobs.length),
                    style: context.text.labelMedium!.copyWith(
                      color: context.colors.muted,
                    ),
                  ),
                );
              }
              final s = jobs[i - 1];
              return JobCard(
                scored: s,
                selected: split && selected?.job == s.job,
                isFavorite: favs.containsKey(FavoritesCubit.keyOf(s.job)),
                onFavoriteChanged: (_) =>
                    context.read<FavoritesCubit>().toggle(s),
                onTap: () => onSelect(s, split),
              );
            },
          ),
        ),
    };
  }
}
