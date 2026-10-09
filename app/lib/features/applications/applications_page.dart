import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/load_status.dart';
import '../../core/design/design.dart';
import '../../core/open_link.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/data_state_view.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/status_badge.dart';
import '../../l10n/app_localizations.dart';
import 'applications_cubit.dart';
import 'domain/application_record.dart';

String applicationStageLabel(AppLocalizations l, ApplicationStage s) =>
    switch (s) {
      ApplicationStage.applied => l.applicationStageApplied,
      ApplicationStage.screening => l.applicationStageScreening,
      ApplicationStage.interview => l.applicationStageInterview,
      ApplicationStage.offer => l.applicationStageOffer,
      ApplicationStage.rejected => l.applicationStageRejected,
      ApplicationStage.withdrawn => l.applicationStageWithdrawn,
      ApplicationStage.closed => l.applicationStageClosed,
    };

BadgeKind _stageKind(ApplicationStage s) => switch (s) {
  ApplicationStage.offer => BadgeKind.success,
  ApplicationStage.interview || ApplicationStage.screening => BadgeKind.info,
  ApplicationStage.rejected => BadgeKind.error,
  _ => BadgeKind.neutral,
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
          );
        }
        final add = AppButton(
          label: l.applicationsAdd,
          icon: Icons.add,
          onPressed: () => openApplicationForm(context),
        );
        if (s.items.isEmpty) {
          return StateView(
            icon: Icons.assignment_outlined,
            title: l.applicationsTitle,
            body: '${l.applicationsBody}\n\n${l.applicationsDisclaimer}',
            action: add,
          );
        }
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
                Align(alignment: Alignment.centerLeft, child: add),
                const SizedBox(height: AppSpace.s4),
                for (final a in s.items) ...[
                  _ApplicationTile(a),
                  const SizedBox(height: AppSpace.s3),
                ],
              ],
            ),
          ),
        );
      },
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
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: context.read<ApplicationsCubit>(),
              child: ApplicationDetailPage(id: a.id),
            ),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: c.cardBg,
            border: Border.all(color: c.cardBorder),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
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
                    Text(date, style: t.labelMedium!.copyWith(color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              StatusBadge(
                label: applicationStageLabel(l, a.stage),
                kind: _stageKind(a.stage),
              ),
            ],
          ),
        ),
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

  @override
  void dispose() {
    for (final c in [_company, _title, _link, _channel, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
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
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? l.commonRequired : null;
    return Scaffold(
      appBar: AppBar(title: Text(l.applicationNewTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.s4),
              children: [
                Text(
                  l.applicationsDisclaimer,
                  style: context.text.bodySmall!.copyWith(
                    color: context.colors.muted,
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(labelText: l.applicationJobTitle),
                  maxLength: 200,
                  validator: required,
                ),
                TextFormField(
                  controller: _company,
                  decoration: InputDecoration(labelText: l.applicationCompany),
                  maxLength: 200,
                  validator: required,
                ),
                TextFormField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: '${l.applicationLink} (${l.commonOptional})',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ||
                          ApplicationsCubit.isWebLink(v!.trim())
                      ? null
                      : l.applicationLinkInvalid,
                ),
                const SizedBox(height: AppSpace.s3),
                DropdownButtonFormField<ApplicationStage>(
                  initialValue: _stage,
                  decoration: InputDecoration(
                    labelText: l.applicationStageLabel,
                  ),
                  items: [
                    for (final s in ApplicationStage.values)
                      DropdownMenuItem(
                        value: s,
                        child: Text(applicationStageLabel(l, s)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _stage = v ?? _stage),
                ),
                const SizedBox(height: AppSpace.s3),
                TextFormField(
                  controller: _channel,
                  decoration: InputDecoration(
                    labelText: '${l.applicationChannel} (${l.commonOptional})',
                  ),
                  maxLength: 100,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.applicationAppliedOn),
                  subtitle: Text(
                    _date == null
                        ? l.applicationNoDate
                        : MaterialLocalizations.of(context)
                              .formatMediumDate(_date!),
                  ),
                  trailing: _date == null
                      ? const Icon(Icons.event_outlined)
                      : IconButton(
                          tooltip: l.dateClear,
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _date = null),
                        ),
                  onTap: _pickDate,
                ),
                TextFormField(
                  controller: _note,
                  decoration: InputDecoration(
                    labelText: '${l.applicationNote} (${l.commonOptional})',
                  ),
                  maxLines: 4,
                  maxLength: 5000,
                ),
                const SizedBox(height: AppSpace.s4),
                AppButton(
                  label: l.commonSave,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.applicationDeleteTitle),
        content: Text(l.commonDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
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
            body: StateView(
              icon: Icons.search_off,
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
                      child: AppButton(
                        label: l.applicationOpenLink,
                        icon: Icons.open_in_new,
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          final ok = await openExternalLink(a.job.originalUrl);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l.applicationLinkCannotOpen),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s4),
                  DropdownButtonFormField<ApplicationStage>(
                    initialValue: a.stage,
                    decoration: InputDecoration(
                      labelText: l.applicationStageLabel,
                    ),
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
                            if (v != null && v != a.stage) {
                              context.read<ApplicationsCubit>().updateStage(
                                a.id,
                                v,
                              );
                            }
                          },
                  ),
                  const SizedBox(height: AppSpace.s3),
                  TextField(
                    controller: _note,
                    decoration: InputDecoration(labelText: l.applicationNote),
                    maxLines: 4,
                    maxLength: 5000,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton(
                      label: l.applicationSaveNote,
                      variant: AppButtonVariant.secondary,
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
                  SectionHeader(title: l.applicationHistory),
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
