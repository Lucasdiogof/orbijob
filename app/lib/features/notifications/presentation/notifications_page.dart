import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/load_status.dart';
import '../../../core/design/design.dart';
import '../../../core/di/injector.dart';
import '../../../core/format/country_names.dart';
import '../../../core/format/relative_time.dart';
import '../../../core/orbi/orbi.dart';
import '../../../core/widgets/data_state_view.dart';
import '../../shell/shell_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../browser/open_in_app.dart';
import '../../search/data/offline_first_search_repository.dart'
    show classifyCatalogueError;
import '../../search/domain/entities/job_posting.dart';
import '../../search/domain/search_repository.dart';
import '../../search/presentation/pages/job_detail_page.dart';
import '../../searches/presentation/saved_searches_cubit.dart';
import '../../searches/presentation/saved_searches_page.dart';
import '../../searches/presentation/search_labels.dart';
import '../../translation/translation_widgets.dart';
import '../domain/notifications_repository.dart';
import 'notifications_cubit.dart';

/// The notification centre: the jobs announced for the saved searches with alerts on, the switch for all alerts and a way to the searches.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.now});

  /// Clock injection for tests.
  final DateTime? now;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Opening the centre reads again, so what the hourly run just wrote is there.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshAndKeepJobs();
    });
  }

  /// Refreshes the list and keeps the newest jobs it points at, so that opening them works without a connection later.
  Future<void> _refreshAndKeepJobs() async {
    final cubit = context.read<NotificationsCubit>();
    await cubit.refresh();
    final repo = maybe<SearchRepository>();
    if (repo is! JobPrefetch) return;
    final ids = [
      for (final n in cubit.state.items)
        if (!n.kind.isReminder && n.jobId != null) n.jobId!,
    ];
    if (ids.isNotEmpty) await (repo as JobPrefetch).prefetchJobs(ids);
  }

  Future<void> _open(AppNotification n) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<NotificationsCubit>();
    final nav = Navigator.of(context);
    cubit.markRead(n);
    if (n.kind.isReminder) {
      // a reminder is about the person's own application: the pipeline shows it with its dates and notes
      context.read<ShellCubit>().goTo(ShellCubit.applications);
      nav.popUntil((r) => r.isFirst);
      return;
    }
    JobPosting? job;
    var offline = false;
    final repo = maybe<SearchRepository>();
    final id = n.jobId;
    if (id != null && repo is JobLookup) {
      try {
        job = await (repo as JobLookup).jobById(id);
      } catch (e) {
        job = null;
        offline = classifyCatalogueError(e) == CatalogueFailure.offline;
      }
    }
    if (!mounted) return;
    if (job == null && offline) {
      // no connection and this job was never kept on the device: say what is needed instead of "no longer available" and a page that cannot load
      showOrbiSnackBar(context, l.ntJobOffline);
      return;
    }
    if (job != null) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => JobDetailPage(scored: ScoredJob(job!)),
        ),
      );
      return;
    }
    final url = n.originalUrl;
    if (url == null) {
      showOrbiSnackBar(context, l.ntJobUnavailable);
      return;
    }
    showOrbiSnackBar(context, l.ntJobUnavailable);
    await openInApp(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocConsumer<NotificationsCubit, NotificationsState>(
      listenWhen: (a, b) => a.actionTick != b.actionTick,
      listener: (context, s) {
        if (s.actionFailure != null) showDataFailure(context, s.actionFailure!);
      },
      builder: (context, s) {
        final cubit = context.read<NotificationsCubit>();
        return Scaffold(
          appBar: AppBar(
            title: Text(l.ntTitle),
            actions: [
              if (s.unread > 0)
                IconButton(
                  tooltip: l.ntMarkAllRead,
                  icon: const Icon(Icons.done_all_rounded),
                  onPressed: cubit.markAllRead,
                ),
              if (s.items.isNotEmpty)
                IconButton(
                  tooltip: l.ntClearAll,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () async {
                    final ok = await showOrbiConfirm(
                      context,
                      title: l.ntClearTitle,
                      message: l.ntClearBody,
                      confirmLabel: l.ntClearAll,
                      destructive: true,
                    );
                    if (ok) cubit.dismissAll();
                  },
                ),
            ],
          ),
          body: _body(context, s),
        );
      },
    );
  }

  Widget _body(BuildContext context, NotificationsState s) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<NotificationsCubit>();
    if (s.status == LoadStatus.loading) return const DataLoadingView();
    if (s.status == LoadStatus.failure) {
      return DataFailureView(
        kind: s.failure!,
        onRetry: cubit.load,
        gate: OrbiGateKind.savedSearches,
        onContinue: () => Navigator.of(context).maybePop(),
      );
    }
    final now = widget.now ?? DateTime.now();
    final names = _searchNames(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: RefreshIndicator(
          onRefresh: cubit.refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: [
              OrbiCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s4,
                  AppSpace.s2,
                  AppSpace.s2,
                  AppSpace.s2,
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  value: s.alertsEnabled,
                  onChanged: s.busy ? null : cubit.setAlertsEnabled,
                  title: Text(l.ntEnabled),
                  subtitle: Text(l.ntEnabledHelp),
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OrbiTextButton(
                  label: l.ntManageSearches,
                  icon: Icons.bookmarks_outlined,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SavedSearchesPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              if (s.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
                  child: OrbiEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: l.ntEmptyTitle,
                    body: _noAlerts(context)
                        ? l.ntEmptyNoAlerts
                        : l.ntEmptyBody,
                    kind: OrbiStateKind.info,
                  ),
                )
              else
                for (final (i, n) in s.items.indexed) ...[
                  Reveal(
                    index: i,
                    child: _NotificationCard(
                      n: n,
                      now: now,
                      searchNames: [for (final id in n.searchIds) ?names[id]],
                      onTap: () => _open(n),
                      onDismiss: () => cubit.dismiss(n),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s3),
                ],
              const SizedBox(height: AppSpace.s2),
              Text(l.ntPushNote, style: context.metadataStyle),
            ],
          ),
        ),
      ),
    );
  }

  bool _noAlerts(BuildContext context) {
    try {
      final c = context.read<SavedSearchesCubit>();
      return c.state.status == LoadStatus.ready && c.alertCount == 0;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _searchNames(BuildContext context) {
    try {
      final l = AppLocalizations.of(context);
      final lang = langOf(context);
      return {
        for (final s in context.read<SavedSearchesCubit>().state.items)
          s.id: savedSearchTitle(s, l, lang),
      };
    } catch (_) {
      return const {};
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.n,
    required this.now,
    required this.searchNames,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotification n;
  final DateTime now;
  final List<String> searchNames;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  /// The job behind a job alert, enough for the shared translation of titles (the original title is always kept).
  JobPosting? get _job => n.kind.isReminder
      ? null
      : JobPosting(
          source: n.sourceId ?? 'notification',
          externalId: n.jobId ?? n.id,
          company: n.company ?? '',
          title: n.title,
          originalUrl: n.originalUrl ?? '',
          country: n.country,
        );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final lang = langOf(context);
    final where = [
      if ((n.company ?? '').isNotEmpty) n.company!,
      if (n.country != null) countryName(n.country!, lang) ?? n.country!,
    ].join(' · ');
    final shown = searchNames.take(2).join(', ');
    final more = searchNames.length - 2;
    final from = searchNames.isEmpty
        ? null
        : (more > 0
              ? l.ntFromSearchesMore(shown, more)
              : l.ntFromSearches(shown));
    final (kindLabel, kindIcon, kindFg, kindBg) = switch (n.kind) {
      NotificationKind.newJob => (
        l.ntKindNewJob,
        Icons.work_outline_rounded,
        c.onPrimaryContainer,
        c.primaryContainer,
      ),
      NotificationKind.interview => (
        l.ntKindInterview,
        Icons.event_available_outlined,
        c.onSuccessContainer,
        c.successContainer,
      ),
      NotificationKind.followUp => (
        l.ntKindFollowUp,
        Icons.reply_outlined,
        c.onWarningContainer,
        c.warningContainer,
      ),
    };
    final titleStyle = n.unread
        ? context.text.titleMedium
        : context.text.titleMedium!.copyWith(
            color: c.muted,
            fontWeight: FontWeight.w500,
          );
    Widget title(String t, bool translated) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: t),
          if (translated)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: 6),
                child: TranslatedMark(),
              ),
            ),
        ],
      ),
      style: titleStyle,
    );
    final job = _job;
    return Semantics(
      container: true,
      label: '$kindLabel. ${n.unread ? '${l.ntUnread}: ' : ''}${n.title}',
      child: OrbiCard(
        // unread reads at a glance: the card takes the brand edge until it is opened
        selected: n.unread,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s3,
          AppSpace.s1,
          AppSpace.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpace.s2,
                    runSpacing: AppSpace.s1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s2,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kindBg,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(kindIcon, size: 14, color: kindFg),
                              const SizedBox(width: 4),
                              Text(
                                kindLabel,
                                style: context.text.labelMedium!.copyWith(
                                  color: kindFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        agoLabel(n.createdAt, now, l),
                        style: context.metadataStyle,
                      ),
                      if (n.unread)
                        ExcludeSemantics(
                          child: Icon(Icons.circle, size: 8, color: c.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s1),
                  if (job == null)
                    title(n.title, false)
                  else
                    TranslatedTitle(
                      job: job,
                      builder: (context, t, translated) => title(t, translated),
                    ),
                  if (where.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(where, style: context.text.bodyMedium),
                  ],
                  if (n.kind.isReminder) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.kind == NotificationKind.interview
                          ? l.ntReminderInterview
                          : l.ntReminderFollowUp,
                      style: context.metadataStyle,
                    ),
                  ] else if (from != null) ...[
                    const SizedBox(height: 2),
                    Text(from, style: context.metadataStyle),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: l.ntDismiss,
              icon: const Icon(Icons.close_rounded),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
