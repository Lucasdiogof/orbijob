import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/orbi/orbi.dart';
import '../../core/widgets/data_state_view.dart';
import '../../l10n/app_localizations.dart';
import '../applications/applications_cubit.dart';
import '../hidden/domain/hidden_jobs_repository.dart';
import '../hidden/presentation/hidden_jobs_cubit.dart';
import '../search/domain/entities/job_posting.dart';

/// Hides [job] and offers to undo it. Used by the card menu and the detail page. The cubit shows at once and reports a refusal through the
/// scope's failure listener, so nothing here waits on the card still being on screen.
void hideJobWithUndo(BuildContext context, JobPosting job) {
  final hidden = context.read<HiddenJobsCubit>();
  final l = AppLocalizations.of(context);
  final key = hiddenKey(job);
  hidden.hide(job);
  showOrbiSnackBar(
    context,
    l.hdHidden,
    actionLabel: l.hdUndo,
    onAction: () => hidden.restore(key),
  );
}

/// Adds [job] to the applications as "interested": a way to keep an eye on it. Nothing is sent and no application date is recorded.
Future<void> trackJobInterest(BuildContext context, JobPosting job) async {
  final cubit = context.read<ApplicationsCubit>();
  final l = AppLocalizations.of(context);
  if (cubit.isTracked(job)) {
    showOrbiSnackBar(context, l.apAlreadyTracked);
    return;
  }
  final ok = await cubit.trackInterest(job);
  if (!context.mounted) return;
  if (ok) {
    showOrbiSnackBar(context, l.apTrackedInterest, kind: OrbiSnackKind.success);
  } else {
    final f = cubit.state.actionFailure;
    if (f != null) showDataFailure(context, f);
  }
}

enum _JobAction { track, hide }

/// The "more" menu of a job: follow it in the applications, hide it (and, as they arrive, share and compare). Draws nothing when the account
/// features are not available in this build.
class JobActionsMenu extends StatelessWidget {
  const JobActionsMenu({super.key, required this.job, this.onHidden});
  final JobPosting job;

  /// Called after the job was hidden (the detail page closes itself).
  final VoidCallback? onHidden;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    HiddenJobsCubit? hidden;
    try {
      hidden = context.read<HiddenJobsCubit>();
    } catch (_) {
      hidden = null;
    }
    if (hidden == null) return const SizedBox.shrink();
    return PopupMenuButton<_JobAction>(
      tooltip: l.jobMoreActions(job.title),
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (a) {
        switch (a) {
          case _JobAction.track:
            trackJobInterest(context, job);
          case _JobAction.hide:
            hideJobWithUndo(context, job);
            onHidden?.call();
        }
      },
      itemBuilder: (_) => [
        _item(_JobAction.track, Icons.assignment_outlined, l.apTrackInterest),
        _item(_JobAction.hide, Icons.visibility_off_outlined, l.hdHide),
      ],
    );
  }

  PopupMenuItem<_JobAction> _item(_JobAction a, IconData icon, String label) =>
      PopupMenuItem(
        value: a,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Flexible(child: Text(label)),
          ],
        ),
      );
}
