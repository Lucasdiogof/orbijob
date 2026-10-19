import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/load_status.dart';
import '../../core/design/design.dart';
import '../../core/orbi/orbi.dart';
import '../../core/widgets/data_state_view.dart';
import '../../l10n/app_localizations.dart';
import '../search/presentation/pages/job_detail_page.dart';
import '../search/presentation/widgets/saved_results_notice.dart';
import '../shell/shell_cubit.dart';
import 'favorites_cubit.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocConsumer<FavoritesCubit, FavoritesState>(
      listenWhen: (a, b) => a.actionTick != b.actionTick,
      listener: (context, s) {
        if (s.actionFailure != null) showDataFailure(context, s.actionFailure!);
      },
      builder: (context, s) => AnimatedSwitcher(
        duration: reduceMotion(context) ? Duration.zero : AppMotion.base,
        child: KeyedSubtree(
          key: ValueKey(s.status == LoadStatus.ready && s.items.isEmpty),
          child: _body(context, s, l),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, FavoritesState s, AppLocalizations l) {
    {
      if (s.status == LoadStatus.loading) return const DataLoadingView();
      if (s.status == LoadStatus.failure) {
        return DataFailureView(
          kind: s.failure!,
          onRetry: () => context.read<FavoritesCubit>().load(),
          gate: OrbiGateKind.favorites,
          onContinue: () => context.read<ShellCubit>().goTo(ShellCubit.explore),
        );
      }
      if (s.items.isEmpty) {
        return OrbiEmptyState(
          icon: Icons.bookmark_border_rounded,
          title: l.favoritesTitle,
          body: l.favoritesBody,
          action: OrbiPrimaryButton(
            label: l.gateKeepExploring,
            icon: Icons.explore_outlined,
            onPressed: () =>
                context.read<ShellCubit>().goTo(ShellCubit.explore),
          ),
        );
      }
      final jobs = s.items.values.toList();
      final savedAt = s.cachedAt;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _withSavedNotice(
            context,
            savedAt,
            ListView.separated(
              padding: const EdgeInsets.all(AppSpace.s4),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
              itemBuilder: (context, i) => OrbiJobCard(
                scored: jobs[i],
                isFavorite: true,
                onFavoriteChanged: (_) =>
                    context.read<FavoritesCubit>().toggle(jobs[i]),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => JobDetailPage(scored: jobs[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}

/// The copy kept on the device is read-only while there is no connection: it is said, with its date, above the list.
Widget _withSavedNotice(BuildContext context, DateTime? savedAt, Widget list) {
  if (savedAt == null) return list;
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s4,
          AppSpace.s4,
          0,
        ),
        child: SavedResultsNotice(
          savedAt: savedAt,
          onRetry: () => context.read<FavoritesCubit>().load(),
          compact: true,
        ),
      ),
      Expanded(child: list),
    ],
  );
}
