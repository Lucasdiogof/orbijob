import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/favorite_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../favorites/favorites_cubit.dart';
import '../../domain/entities/job_posting.dart';
import '../widgets/job_detail_view.dart';

/// One job on its own page: the details scroll, the call to action stays fixed at the bottom (above the safe area).
class JobDetailPage extends StatelessWidget {
  const JobDetailPage({
    super.key,
    required this.scored,
    this.onOpenApplication,
  });

  final ScoredJob scored;
  final VoidCallback? onOpenApplication;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final hasActions = JobDetailActions.hasActions(
      scored.job,
      onOpenApplication,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.jobDetailTitle),
        leading: const BackButton(),
        actions: [
          BlocBuilder<FavoritesCubit, FavoritesState>(
            builder: (context, favs) => FavoriteButton(
              isFavorite: favs.items.containsKey(
                FavoritesCubit.keyOf(scored.job),
              ),
              onChanged: (_) => context.read<FavoritesCubit>().toggle(scored),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: JobDetailView(
            scored: scored,
            onOpenApplication: onOpenApplication,
            showActions: false,
          ),
        ),
      ),
      bottomNavigationBar: hasActions
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.hairline)),
              ),
              child: SafeArea(
                top: false,
                child: Align(
                  heightFactor: 1,
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      child: JobDetailActions(
                        job: scored.job,
                        onOpenApplication: onOpenApplication,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
