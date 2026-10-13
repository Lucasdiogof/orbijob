import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/load_status.dart';
import '../../../core/design/design.dart';
import '../../../core/orbi/orbi.dart';
import '../../../core/widgets/data_state_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../search/presentation/cubit/search_cubit.dart';
import '../../shell/shell_cubit.dart';
import '../domain/saved_search.dart';
import '../domain/search_spec.dart';
import 'save_search_sheet.dart';
import 'saved_searches_cubit.dart';
import 'search_labels.dart';

/// Runs [spec] in Explore and brings the person there, closing any page opened on top of the shell.
void openSpecInExplore(BuildContext context, SearchSpec spec) {
  final search = context.read<SearchCubit>();
  final shell = context.read<ShellCubit>();
  Navigator.of(context).popUntil((r) => r.isFirst);
  search.runSpec(spec);
  shell.goTo(ShellCubit.explore);
}

/// The saved searches of the account: open one in Explore, switch its alerts and how often they run, edit, duplicate or delete it.
class SavedSearchesPage extends StatelessWidget {
  const SavedSearchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.ssTitle)),
      body: BlocConsumer<SavedSearchesCubit, SavedSearchesState>(
        listenWhen: (a, b) => a.actionTick != b.actionTick,
        listener: (context, s) {
          if (s.actionFailure != null) {
            showDataFailure(context, s.actionFailure!);
          }
        },
        builder: (context, s) {
          if (s.status == LoadStatus.loading) return const DataLoadingView();
          if (s.status == LoadStatus.failure) {
            return DataFailureView(
              kind: s.failure!,
              onRetry: () => context.read<SavedSearchesCubit>().load(),
              gate: OrbiGateKind.savedSearches,
              onContinue: () => Navigator.of(context).maybePop(),
            );
          }
          if (s.items.isEmpty) {
            return OrbiEmptyState(
              icon: Icons.bookmark_border_rounded,
              title: l.ssEmptyTitle,
              body: l.ssEmptyBody,
              action: OrbiPrimaryButton(
                label: l.ssGoExplore,
                icon: Icons.explore_outlined,
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  context.read<ShellCubit>().goTo(ShellCubit.explore);
                },
              ),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s4),
                children: [
                  Text(l.ssSubtitle, style: context.metadataStyle),
                  const SizedBox(height: AppSpace.s3),
                  for (final item in s.items) ...[
                    SavedSearchCard(item: item, busy: s.busy),
                    const SizedBox(height: AppSpace.s3),
                  ],
                  Text(l.ntPushNote, style: context.metadataStyle),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _Action { open, edit, duplicate, delete }

class SavedSearchCard extends StatelessWidget {
  const SavedSearchCard({super.key, required this.item, this.busy = false});
  final SavedSearch item;
  final bool busy;

  Future<void> _onAction(BuildContext context, _Action a) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<SavedSearchesCubit>();
    final lang = langOf(context);
    final title = savedSearchTitle(item, l, lang);
    switch (a) {
      case _Action.open:
        openSpecInExplore(context, item.spec);
      case _Action.edit:
        await showSaveSearchSheet(context, spec: item.spec, editing: item);
      case _Action.duplicate:
        if (await cubit.duplicate(item.id, name: l.ssCopyName(title)) &&
            context.mounted) {
          showOrbiSnackBar(
            context,
            l.ssDuplicated,
            kind: OrbiSnackKind.success,
          );
        }
      case _Action.delete:
        final ok = await showOrbiConfirm(
          context,
          title: l.ssDeleteTitle,
          message: l.ssDeleteBody,
          confirmLabel: l.ssDelete,
          destructive: true,
        );
        if (ok) {
          await cubit.remove(item.id);
          if (context.mounted) {
            showOrbiSnackBar(context, l.ssRemoved);
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = langOf(context);
    final title = savedSearchTitle(item, l, lang);
    final parts = describeSpec(item.spec, l, lang);
    final cubit = context.read<SavedSearchesCubit>();
    return OrbiCard(
      onTap: () => openSpecInExplore(context, item.spec),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s2),
                  child: Text(title, style: context.text.titleMedium),
                ),
              ),
              PopupMenuButton<_Action>(
                tooltip: l.ssMenu(title),
                onSelected: (a) => _onAction(context, a),
                itemBuilder: (_) => [
                  PopupMenuItem(value: _Action.open, child: Text(l.ssOpen)),
                  PopupMenuItem(value: _Action.edit, child: Text(l.ssEdit)),
                  PopupMenuItem(
                    value: _Action.duplicate,
                    child: Text(l.ssDuplicate),
                  ),
                  PopupMenuItem(value: _Action.delete, child: Text(l.ssDelete)),
                ],
              ),
            ],
          ),
          if (parts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.s2),
              child: Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s1,
                children: [for (final p in parts) OrbiStatusBadge(label: p)],
              ),
            ),
          const SizedBox(height: AppSpace.s1),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.alertsEnabled
                      ? '${l.ssAlertsOn} · ${frequencyLabel(item.frequency, l)}'
                      : l.ssAlertsOff,
                  style: context.metadataStyle,
                ),
              ),
              Semantics(
                label: l.ssAlertsToggle(title),
                child: Switch.adaptive(
                  value: item.alertsEnabled,
                  onChanged: busy ? null : (v) => cubit.setAlerts(item.id, v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
