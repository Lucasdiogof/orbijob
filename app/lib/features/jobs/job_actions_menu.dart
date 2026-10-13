import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injector.dart';
import '../../core/orbi/orbi.dart';
import '../../core/widgets/data_state_view.dart';
import '../../l10n/app_localizations.dart';
import '../applications/applications_cubit.dart';
import '../browser/link_share.dart';
import '../compare/compare_cubit.dart';
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

/// The text shared for a job: its title and company and the listing's own link. Nothing else (no tracking parameters, no description).
/// Null when the listing has no web link to share.
String? shareTextFor(JobPosting job) {
  final u = Uri.tryParse(job.originalUrl.trim());
  if (u == null ||
      !(u.scheme == 'https' || u.scheme == 'http') ||
      u.host.isEmpty) {
    return null;
  }
  final head = job.company.trim().isEmpty
      ? job.title
      : '${job.title} — ${job.company.trim()}';
  return '$head\n$u';
}

/// Opens the system share sheet with [shareTextFor]. Where sharing is not available (some desktop browsers) the text is copied instead and
/// the person is told.
Future<void> shareJob(BuildContext context, JobPosting job) async {
  final l = AppLocalizations.of(context);
  final text = shareTextFor(job);
  if (text == null) {
    showOrbiSnackBar(context, l.shNoLink);
    return;
  }
  final share = sl<TextShare>();
  try {
    await share(text, subject: job.title);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showOrbiSnackBar(context, l.shCopied);
  }
}

/// Adds the job to (or removes it from) the comparison and says what happened, including that a fourth job does not fit.
void toggleCompare(BuildContext context, JobPosting job) {
  final l = AppLocalizations.of(context);
  switch (context.read<CompareCubit>().toggle(job)) {
    // The bar above the navigation is the confirmation; a snackbar would sit on top of its button.
    case CompareChange.added:
    case CompareChange.removed:
      break;
    case CompareChange.full:
      showOrbiSnackBar(
        context,
        l.cpFull(CompareCubit.maxJobs),
        kind: OrbiSnackKind.error,
      );
  }
}

enum _JobAction { share, compare, track, hide }

T? _maybe<T extends StateStreamable<Object?>>(BuildContext context) {
  try {
    return context.read<T>();
  } catch (_) {
    return null;
  }
}

/// The "more" menu of a job: share it, compare it, follow it in the applications, hide it. Each entry is offered only when its part of the app
/// is there (a build without an account has nothing to hide or follow).
class JobActionsMenu extends StatelessWidget {
  const JobActionsMenu({super.key, required this.job, this.onHidden});
  final JobPosting job;

  /// Called after the job was hidden (the detail page closes itself).
  final VoidCallback? onHidden;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasHidden = _maybe<HiddenJobsCubit>(context) != null;
    final hasApps = _maybe<ApplicationsCubit>(context) != null;
    final compare = _maybe<CompareCubit>(context);
    final canShare = shareTextFor(job) != null;
    final picked = compare?.contains(job) ?? false;
    final entries = <PopupMenuItem<_JobAction>>[
      if (canShare) _item(_JobAction.share, Icons.ios_share_rounded, l.shShare),
      if (compare != null)
        _item(
          _JobAction.compare,
          picked ? Icons.playlist_remove_rounded : Icons.compare_arrows_rounded,
          picked ? l.cpRemove : l.cpAdd,
        ),
      if (hasApps)
        _item(_JobAction.track, Icons.assignment_outlined, l.apTrackInterest),
      if (hasHidden)
        _item(_JobAction.hide, Icons.visibility_off_outlined, l.hdHide),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<_JobAction>(
      tooltip: l.jobMoreActions(job.title),
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (a) {
        switch (a) {
          case _JobAction.share:
            shareJob(context, job);
          case _JobAction.compare:
            toggleCompare(context, job);
          case _JobAction.track:
            trackJobInterest(context, job);
          case _JobAction.hide:
            hideJobWithUndo(context, job);
            onHidden?.call();
        }
      },
      itemBuilder: (_) => entries,
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
