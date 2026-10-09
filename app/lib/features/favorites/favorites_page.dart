import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/load_status.dart';
import '../../core/design/design.dart';
import '../../core/widgets/data_state_view.dart';
import '../../core/widgets/state_view.dart';
import '../../l10n/app_localizations.dart';
import '../search/presentation/pages/job_detail_page.dart';
import '../search/presentation/widgets/job_card.dart';
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
      builder: (context, s) {
        if (s.status == LoadStatus.loading) return const DataLoadingView();
        if (s.status == LoadStatus.failure) {
          return DataFailureView(
            kind: s.failure!,
            onRetry: () => context.read<FavoritesCubit>().load(),
          );
        }
        if (s.items.isEmpty) {
          return StateView(
            icon: Icons.favorite_border,
            title: l.favoritesTitle,
            body: l.favoritesBody,
          );
        }
        final jobs = s.items.values.toList();
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpace.s4),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
              itemBuilder: (context, i) => JobCard(
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
        );
      },
    );
  }
}
