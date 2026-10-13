import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/load_status.dart';
import '../../../core/design/design.dart';
import '../../../core/format/relative_time.dart';
import '../../../core/orbi/orbi.dart';
import '../../../core/widgets/data_state_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../browser/open_in_app.dart';
import '../../shell/shell_cubit.dart';
import '../domain/hidden_jobs_repository.dart';
import 'hidden_jobs_cubit.dart';

/// The jobs the person hid, with a way to bring each back. Hidden jobs stay out of search, recommendations and alerts until restored.
class HiddenJobsPage extends StatelessWidget {
  const HiddenJobsPage({super.key, this.now});
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.hdTitle)),
      body: BlocBuilder<HiddenJobsCubit, HiddenJobsState>(
        builder: (context, s) {
          if (s.status == LoadStatus.loading) return const DataLoadingView();
          if (s.status == LoadStatus.failure) {
            return DataFailureView(
              kind: s.failure!,
              onRetry: () => context.read<HiddenJobsCubit>().load(),
              gate: OrbiGateKind.favorites,
              onContinue: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                context.read<ShellCubit>().goTo(ShellCubit.explore);
              },
            );
          }
          if (s.items.isEmpty) {
            return OrbiEmptyState(
              icon: Icons.visibility_outlined,
              title: l.hdEmptyTitle,
              body: l.hdEmptyBody,
              kind: OrbiStateKind.info,
            );
          }
          final at = now ?? DateTime.now();
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s4),
                children: [
                  Text(l.hdSubtitle, style: context.metadataStyle),
                  const SizedBox(height: AppSpace.s3),
                  for (final h in s.items.values) ...[
                    _HiddenCard(h: h, now: at),
                    const SizedBox(height: AppSpace.s3),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HiddenCard extends StatelessWidget {
  const _HiddenCard({required this.h, required this.now});
  final HiddenJob h;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<HiddenJobsCubit>();
    return OrbiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(h.title, style: context.text.titleMedium),
          if ((h.company ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(h.company!, style: context.text.bodyMedium),
          ],
          const SizedBox(height: AppSpace.s1),
          Text(agoLabel(h.hiddenAt, now, l), style: context.metadataStyle),
          const SizedBox(height: AppSpace.s2),
          Wrap(
            spacing: AppSpace.s2,
            children: [
              OrbiSecondaryButton(
                label: l.hdRestore,
                icon: Icons.visibility_outlined,
                onPressed: () async {
                  final ok = await cubit.restore(h.key);
                  if (ok && context.mounted) {
                    showOrbiSnackBar(
                      context,
                      l.hdRestored,
                      kind: OrbiSnackKind.success,
                    );
                  }
                },
              ),
              if (h.originalUrl != null)
                OrbiTextButton(
                  label: l.hdOpenListing,
                  icon: Icons.open_in_new,
                  onPressed: () => openInApp(context, h.originalUrl!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
