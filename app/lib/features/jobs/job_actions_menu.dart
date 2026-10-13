import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/orbi/orbi.dart';
import '../../l10n/app_localizations.dart';
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

enum _JobAction { hide }

/// The "more" menu of a job: hide it (and, as they arrive, share and compare). Draws nothing when the account features are not available in this
/// build.
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
          case _JobAction.hide:
            hideJobWithUndo(context, job);
            onHidden?.call();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _JobAction.hide,
          child: Row(
            children: [
              const Icon(Icons.visibility_off_outlined, size: 20),
              const SizedBox(width: 12),
              Flexible(child: Text(l.hdHide)),
            ],
          ),
        ),
      ],
    );
  }
}
