import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/load_status.dart';
import '../../core/design/design.dart';
import '../../core/orbi/orbi.dart';
import '../browser/open_in_app.dart';
import '../../core/widgets/data_state_view.dart';
import '../../l10n/app_localizations.dart';
import '../search/presentation/widgets/saved_results_notice.dart';
import '../shell/shell_cubit.dart';
import 'applications_cubit.dart';
import 'domain/application_agenda.dart';
import 'domain/application_record.dart';

String applicationStageLabel(AppLocalizations l, ApplicationStage s) =>
    switch (s) {
      ApplicationStage.interested => l.applicationStageInterested,
      ApplicationStage.hired => l.applicationStageHired,
      ApplicationStage.applied => l.applicationStageApplied,
      ApplicationStage.screening => l.applicationStageScreening,
      ApplicationStage.interview => l.applicationStageInterview,
      ApplicationStage.offer => l.applicationStageOffer,
      ApplicationStage.rejected => l.applicationStageRejected,
      ApplicationStage.withdrawn => l.applicationStageWithdrawn,
      ApplicationStage.closed => l.applicationStageClosed,
    };

OrbiBadgeKind _stageKind(ApplicationStage s) => switch (s) {
  ApplicationStage.offer || ApplicationStage.hired => OrbiBadgeKind.success,
  ApplicationStage.interview ||
  ApplicationStage.screening => OrbiBadgeKind.info,
  ApplicationStage.rejected => OrbiBadgeKind.error,
  _ => OrbiBadgeKind.neutral,
};

/// Applications the user tracks. OrbiJob never sends an application: everything here was registered by hand.
class ApplicationsPage extends StatelessWidget {
  const ApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocConsumer<ApplicationsCubit, ApplicationsState>(
      listenWhen: (a, b) => a.actionTick != b.actionTick,
      listener: (context, s) {
        if (s.actionFailure != null) showDataFailure(context, s.actionFailure!);
      },
      builder: (context, s) {
        if (s.status == LoadStatus.loading) return const DataLoadingView();
        if (s.status == LoadStatus.failure) {
          return DataFailureView(
            kind: s.failure!,
            onRetry: () => context.read<ApplicationsCubit>().load(),
            gate: OrbiGateKind.applications,
            onContinue: () =>
                context.read<ShellCubit>().goTo(ShellCubit.explore),
          );
        }
        final add = OrbiPrimaryButton(
          label: l.applicationsAdd,
          icon: Icons.add_rounded,
          onPressed: () => openApplicationForm(context),
        );
        if (s.items.isEmpty) {
          return OrbiEmptyState(
            icon: Icons.assignment_outlined,
            title: l.applicationsTitle,
            body: '${l.applicationsBody}\n\n${l.applicationsDisclaimer}',
            action: add,
          );
        }
        final list = _ApplicationsList(items: s.items, add: add);
        final savedAt = s.cachedAt;
        if (savedAt == null) return list;
        // the copy kept on the device is read-only while there is no connection: said, with its date, above the list
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
                onRetry: () => context.read<ApplicationsCubit>().load(),
                compact: true,
              ),
            ),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}

/// The pipeline: what is coming up, a filter by stage with counts, and the applications.
class _ApplicationsList extends StatefulWidget {
  const _ApplicationsList({required this.items, required this.add});
  final List<ApplicationRecord> items;
  final Widget add;

  @override
  State<_ApplicationsList> createState() => _ApplicationsListState();
}

class _ApplicationsListState extends State<_ApplicationsList> {
  ApplicationStage? _filter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = widget.items;
    final agenda = buildAgenda(items, DateTime.now()).take(4).toList();
    final counts = {
      for (final st in ApplicationStage.values)
        st: items.where((a) => a.stage == st).length,
    };
    final filter = (_filter != null && (counts[_filter] ?? 0) > 0)
        ? _filter
        : null;
    final shown = filter == null
        ? items
        : [
            for (final a in items)
              if (a.stage == filter) a,
          ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s4),
          children: [
            Text(
              l.applicationsDisclaimer,
              style: context.text.bodySmall!.copyWith(
                color: context.colors.muted,
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            Align(alignment: Alignment.centerLeft, child: widget.add),
            if (agenda.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s5),
              OrbiSectionHeader(title: l.apAgendaTitle),
              const SizedBox(height: AppSpace.s3),
              for (final e in agenda) ...[
                _AgendaTile(e),
                const SizedBox(height: AppSpace.s2),
              ],
            ],
            const SizedBox(height: AppSpace.s4),
            OrbiChipRow(
              padding: EdgeInsets.zero,
              children: [
                OrbiFilterChip(
                  label: l.apPipelineCount(l.apPipelineAll, items.length),
                  selected: filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final st in ApplicationStage.values)
                  if ((counts[st] ?? 0) > 0)
                    OrbiFilterChip(
                      label: l.apPipelineCount(
                        applicationStageLabel(l, st),
                        counts[st]!,
                      ),
                      selected: filter == st,
                      onSelected: (_) =>
                          setState(() => _filter = filter == st ? null : st),
                    ),
              ],
            ),
            const SizedBox(height: AppSpace.s3),
            // changing the stage filter cross-fades the list instead of swapping it
            AnimatedSwitcher(
              duration: reduceMotion(context) ? Duration.zero : AppMotion.base,
              child: Column(
                key: ValueKey(filter),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (shown.isEmpty)
                    Text(l.apFilteredEmpty, style: context.metadataStyle)
                  else
                    // all stages: grouped under one header per stage, in pipeline order (presentation only; the list and
                    // its order inside a stage are the same as before). One stage selected: the plain list.
                    for (final st in ApplicationStage.values)
                      if (filter == null && (counts[st] ?? 0) > 0) ...[
                        if (counts.values.where((n) => n > 0).length > 1)
                          _StageHeader(stage: st, count: counts[st]!),
                        for (final a in shown)
                          if (a.stage == st) ...[
                            _ApplicationTile(a),
                            const SizedBox(height: AppSpace.s3),
                          ],
                      ] else if (filter == st)
                        for (final a in shown) ...[
                          _ApplicationTile(a),
                          const SizedBox(height: AppSpace.s3),
                        ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header of a stage group: the stage badge with its count, announced as a heading.
class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.stage, required this.count});
  final ApplicationStage stage;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = l.apPipelineCount(applicationStageLabel(l, stage), count);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s2, bottom: AppSpace.s2),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          header: true,
          child: OrbiStatusBadge(label: label, kind: _stageKind(stage)),
        ),
      ),
    );
  }
}

String _when(BuildContext context, AgendaKind k, DateTime at) {
  final m = MaterialLocalizations.of(context);
  final day = m.formatMediumDate(at);
  return k == AgendaKind.interview
      ? '$day · ${m.formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}'
      : day;
}

String _kindLabel(AppLocalizations l, AgendaKind k) =>
    k == AgendaKind.interview ? l.apAgendaInterview : l.apAgendaFollowUp;

class _AgendaTile extends StatelessWidget {
  const _AgendaTile(this.e);
  final AgendaItem e;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final a = e.application;
    return OrbiCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: context.read<ApplicationsCubit>(),
            child: ApplicationDetailPage(id: a.id),
          ),
        ),
      ),
      padding: const EdgeInsets.all(AppSpace.s3),
      child: Row(
        children: [
          Icon(
            e.kind == AgendaKind.interview
                ? Icons.event_outlined
                : Icons.alarm_outlined,
            color: e.overdue ? c.error : c.primary,
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_kindLabel(l, e.kind)} · ${a.job.title}',
                  style: context.text.labelLarge,
                ),
                Text(
                  [
                    if (a.job.company.isNotEmpty) a.job.company,
                    _when(context, e.kind, e.at),
                  ].join(' · '),
                  style: context.metadataStyle,
                ),
                if (e.overdue)
                  Text(l.apAgendaOverdueHint, style: context.metadataStyle),
              ],
            ),
          ),
          if (e.overdue)
            OrbiStatusBadge(label: l.apOverdue, kind: OrbiBadgeKind.error),
        ],
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile(this.a);
  final ApplicationRecord a;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final date = a.appliedAt == null
        ? l.applicationNoDate
        : MaterialLocalizations.of(context).formatMediumDate(a.appliedAt!);
    return OrbiCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: context.read<ApplicationsCubit>(),
            child: ApplicationDetailPage(id: a.id),
          ),
        ),
      ),
      child: Row(
        children: [
          if (a.job.company.isNotEmpty &&
              OrbiMonogram.initialOf(a.job.company) != null &&
              MediaQuery.textScalerOf(context).scale(16) <= 22)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.s3),
              child: OrbiMonogram(name: a.job.company),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.job.title, style: t.titleSmall),
                const SizedBox(height: AppSpace.s1),
                Text(
                  a.job.company,
                  style: t.bodyMedium!.copyWith(color: c.muted),
                ),
                const SizedBox(height: AppSpace.s1),
                Text(date, style: context.metadataStyle),
                if (a.nextDate != null)
                  Text(
                    l.apNextDate(
                      a.interviewAt != null
                          ? l.apAgendaInterview
                          : l.apAgendaFollowUp,
                      _when(
                        context,
                        a.interviewAt != null
                            ? AgendaKind.interview
                            : AgendaKind.followUp,
                        a.nextDate!.toLocal(),
                      ),
                    ),
                    style: context.metadataStyle,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s3),
          // a change of stage cross-fades instead of jumping
          AnimatedSwitcher(
            duration: reduceMotion(context) ? Duration.zero : AppMotion.base,
            child: OrbiStatusBadge(
              key: ValueKey(a.stage),
              label: applicationStageLabel(l, a.stage),
              kind: _stageKind(a.stage),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the "new application" form, sharing the page's cubit.
Future<void> openApplicationForm(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BlocProvider.value(
          value: context.read<ApplicationsCubit>(),
          child: const _ApplicationFormPage(),
        ),
      ),
    );

class _ApplicationFormPage extends StatefulWidget {
  const _ApplicationFormPage();
  @override
  State<_ApplicationFormPage> createState() => _ApplicationFormPageState();
}

class _ApplicationFormPageState extends State<_ApplicationFormPage> {
  final _form = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _title = TextEditingController();
  final _link = TextEditingController();
  final _channel = TextEditingController();
  final _note = TextEditingController();
  ApplicationStage _stage = ApplicationStage.applied;
  DateTime? _date;
  bool _saving = false;
  bool _dirty = false;

  @override
  void dispose() {
    for (final c in [_company, _title, _link, _channel, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (!(_form.currentState?.validate() ?? false)) {
      showOrbiSnackBar(context, l.formFixErrors, kind: OrbiSnackKind.error);
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = l.commonSaved;
    final ok = await context.read<ApplicationsCubit>().create(
      company: _company.text,
      title: _title.text,
      link: _link.text,
      channel: _channel.text,
      note: _note.text,
      stage: _stage,
      appliedAt: _date,
    );
    if (!mounted) return;
    if (ok) {
      _dirty = false;
      Navigator.of(context).pop();
      showSavedFeedback(messenger, saved);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? l.commonRequired : null;
    void touch() => _dirty = true;
    return OrbiFormPage(
      title: l.applicationNewTitle,
      formKey: _form,
      saving: _saving,
      dirty: _dirty,
      onSave: _save,
      children: [
        Text(
          l.applicationsDisclaimer,
          style: context.text.bodySmall!.copyWith(color: context.colors.muted),
        ),
        OrbiTextField(
          label: l.applicationJobTitle,
          controller: _title,
          maxLength: 200,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.jobTitle],
          onChanged: (_) => touch(),
          validator: required,
        ),
        OrbiTextField(
          label: l.applicationCompany,
          controller: _company,
          maxLength: 200,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.organizationName],
          onChanged: (_) => touch(),
          validator: required,
        ),
        OrbiTextField(
          label: l.applicationLink,
          optional: true,
          controller: _link,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.url],
          onChanged: (_) => touch(),
          validator: (v) =>
              (v ?? '').trim().isEmpty || ApplicationsCubit.isWebLink(v!.trim())
              ? null
              : l.applicationLinkInvalid,
        ),
        OrbiDropdownField<ApplicationStage>(
          label: l.applicationStageLabel,
          value: _stage,
          items: [
            for (final s in ApplicationStage.values)
              DropdownMenuItem(
                value: s,
                child: Text(applicationStageLabel(l, s)),
              ),
          ],
          onChanged: (v) => setState(() {
            _stage = v;
            _dirty = true;
          }),
        ),
        OrbiTextField(
          label: l.applicationChannel,
          optional: true,
          controller: _channel,
          maxLength: 100,
          textInputAction: TextInputAction.next,
          onChanged: (_) => touch(),
        ),
        OrbiDateField(
          label: l.applicationAppliedOn,
          value: _date,
          lastDate: now,
          firstDate: DateTime(now.year - 10),
          onChanged: (d) => setState(() {
            _date = d;
            _dirty = true;
          }),
        ),
        OrbiTextField(
          label: l.applicationNote,
          optional: true,
          controller: _note,
          maxLines: 4,
          maxLength: 5000,
          textInputAction: TextInputAction.newline,
          onChanged: (_) => touch(),
        ),
      ],
    );
  }
}

class ApplicationDetailPage extends StatefulWidget {
  const ApplicationDetailPage({super.key, required this.id});
  final String id;
  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  final _note = TextEditingController();
  bool _noteInit = false;

  @override
  void initState() {
    super.initState();
    context.read<ApplicationsCubit>().loadHistory(widget.id);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<ApplicationsCubit>();
    final nav = Navigator.of(context);
    final ok = await showOrbiConfirm(
      context,
      title: l.applicationDeleteTitle,
      message: l.commonDeleteConfirmBody,
      confirmLabel: l.commonDelete,
      cancelLabel: l.commonCancel,
      destructive: true,
    );
    if (ok) {
      await cubit.delete(widget.id);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.text;
    final c = context.colors;
    return BlocBuilder<ApplicationsCubit, ApplicationsState>(
      builder: (context, s) {
        final a = s.items.where((e) => e.id == widget.id).firstOrNull;
        if (a == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.applicationDetailTitle)),
            body: OrbiEmptyState(
              icon: Icons.search_off_rounded,
              title: l.dataFailureNotFound,
            ),
          );
        }
        if (!_noteInit) {
          _note.text = a.note ?? '';
          _noteInit = true;
        }
        final events = s.history[a.id];
        final hasLink = a.job.originalUrl.isNotEmpty;
        final fmt = MaterialLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(l.applicationDetailTitle),
            actions: [
              IconButton(
                tooltip: l.commonDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s4),
                children: [
                  Text(a.job.title, style: t.titleLarge),
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    a.job.company,
                    style: t.bodyLarge!.copyWith(color: c.muted),
                  ),
                  if (a.appliedAt != null) ...[
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      '${l.applicationAppliedOn} ${fmt.formatMediumDate(a.appliedAt!)}',
                      style: t.labelMedium!.copyWith(color: c.muted),
                    ),
                  ],
                  if (a.channel != null) ...[
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      '${l.applicationChannel}: ${a.channel}',
                      style: t.labelMedium!.copyWith(color: c.muted),
                    ),
                  ],
                  if (hasLink) ...[
                    const SizedBox(height: AppSpace.s3),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OrbiSecondaryButton(
                        label: l.applicationOpenLink,
                        icon: Icons.open_in_new_rounded,
                        onPressed: () => openInApp(context, a.job.originalUrl),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s4),
                  OrbiDropdownField<ApplicationStage>(
                    label: l.applicationStageLabel,
                    value: a.stage,
                    items: [
                      for (final st in ApplicationStage.values)
                        DropdownMenuItem(
                          value: st,
                          child: Text(applicationStageLabel(l, st)),
                        ),
                    ],
                    onChanged: s.busy
                        ? null
                        : (v) {
                            if (v != a.stage) {
                              context.read<ApplicationsCubit>().updateStage(
                                a.id,
                                v,
                              );
                            }
                          },
                  ),
                  const SizedBox(height: AppSpace.s1),
                  Text(l.apStageHint, style: context.metadataStyle),
                  const SizedBox(height: AppSpace.s4),
                  OrbiSectionHeader(title: l.apDatesTitle),
                  const SizedBox(height: AppSpace.s2),
                  _DateRow(
                    label: l.apInterviewLabel,
                    value: a.interviewAt?.toLocal(),
                    withTime: true,
                    busy: s.busy,
                    onChanged: (d) =>
                        context.read<ApplicationsCubit>().setInterview(a.id, d),
                  ),
                  _DateRow(
                    label: l.apFollowUpLabel,
                    value: a.followUpAt?.toLocal(),
                    withTime: false,
                    busy: s.busy,
                    onChanged: (d) =>
                        context.read<ApplicationsCubit>().setFollowUp(a.id, d),
                  ),
                  const SizedBox(height: AppSpace.s3),
                  OrbiTextField(
                    label: l.applicationNote,
                    controller: _note,
                    maxLines: 4,
                    maxLength: 5000,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OrbiSecondaryButton(
                      label: l.applicationSaveNote,
                      loading: s.busy,
                      onPressed: s.busy
                          ? null
                          : () => context.read<ApplicationsCubit>().updateNote(
                              a.id,
                              _note.text,
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),
                  OrbiSectionHeader(title: l.applicationHistory),
                  const SizedBox(height: AppSpace.s3),
                  if (events == null)
                    const SizedBox(height: 48, child: DataLoadingView())
                  else if (events.isEmpty)
                    Text(
                      l.applicationHistoryEmpty,
                      style: t.bodyMedium!.copyWith(color: c.muted),
                    )
                  else
                    for (final e in events)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(applicationStageLabel(l, e.stage)),
                        subtitle: Text(fmt.formatMediumDate(e.occurredAt)),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A date the person keeps for a process (interview with a time, or a follow-up day): shown, chosen with the platform pickers, cleared.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.withTime,
    required this.onChanged,
    this.busy = false,
  });
  final String label;
  final DateTime? value;
  final bool withTime;
  final bool busy;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !context.mounted) return;
    if (!withTime) return onChanged(DateTime(date.year, date.month, date.day));
    final time = await showTimePicker(
      context: context,
      initialTime: value == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(value!),
    );
    if (time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final m = MaterialLocalizations.of(context);
    final v = value;
    final text = v == null
        ? l.apDateNone
        : (withTime
              ? _when(context, AgendaKind.interview, v)
              : m.formatMediumDate(v));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrbiFieldLabel(label),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpace.s2,
            children: [
              Text(text, style: context.text.bodyLarge),
              OrbiTextButton(
                label: l.apDatePick,
                icon: withTime ? Icons.schedule : Icons.calendar_today_outlined,
                onPressed: busy ? null : () => _pick(context),
              ),
              if (v != null)
                OrbiTextButton(
                  label: l.apDateClear,
                  onPressed: busy ? null : () => onChanged(null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
