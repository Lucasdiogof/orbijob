import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/load_status.dart';
import '../../../core/design/design.dart';
import '../../../core/di/injector.dart';
import '../../../core/format/country_names.dart';
import '../../../core/format/relative_time.dart';
import '../../../core/orbi/orbi.dart';
import '../../../core/widgets/data_state_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../browser/open_in_app.dart';
import '../../search/domain/entities/job_posting.dart';
import '../../search/domain/search_repository.dart';
import '../../search/presentation/pages/job_detail_page.dart';
import '../../searches/presentation/saved_searches_cubit.dart';
import '../../searches/presentation/saved_searches_page.dart';
import '../../searches/presentation/search_labels.dart';
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
      if (mounted) context.read<NotificationsCubit>().refresh();
    });
  }

  Future<void> _open(AppNotification n) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<NotificationsCubit>();
    final nav = Navigator.of(context);
    cubit.markRead(n);
    JobPosting? job;
    final repo = maybe<SearchRepository>();
    final id = n.jobId;
    if (id != null && repo is JobLookup) {
      try {
        job = await (repo as JobLookup).jobById(id);
      } catch (_) {
        job = null;
      }
    }
    if (!mounted) return;
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
                for (final n in s.items) ...[
                  _NotificationCard(
                    n: n,
                    now: now,
                    searchNames: [for (final id in n.searchIds) ?names[id]],
                    onTap: () => _open(n),
                    onDismiss: () => cubit.dismiss(n),
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
    return Semantics(
      container: true,
      label: n.unread ? '${l.ntUnread}: ${n.title}' : n.title,
      child: OrbiCard(
        onTap: onTap,
        selected: n.unread,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s3,
          AppSpace.s1,
          AppSpace.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: AppSpace.s3),
              child: n.unread
                  ? Icon(Icons.circle, size: 10, color: c.primary)
                  : const SizedBox(width: 10),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: n.unread
                        ? context.text.titleMedium
                        : context.text.titleMedium!.copyWith(color: c.muted),
                  ),
                  if (where.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(where, style: context.text.bodyMedium),
                  ],
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    l.ntFound(agoLabel(n.createdAt, now, l)),
                    style: context.metadataStyle,
                  ),
                  if (from != null) Text(from, style: context.metadataStyle),
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
