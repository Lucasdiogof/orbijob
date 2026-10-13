import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/orbi/orbi.dart';
import '../../../core/widgets/data_state_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/saved_search.dart';
import '../domain/search_spec.dart';
import '../../search/presentation/cubit/search_cubit.dart';
import 'saved_searches_cubit.dart';
import 'search_labels.dart';

/// Saves [spec] as a new search, or edits [editing]. Returns true when something was stored.
Future<bool> showSaveSearchSheet(
  BuildContext context, {
  required SearchSpec spec,
  SavedSearch? editing,
}) async {
  final cubit = context.read<SavedSearchesCubit>();
  final ok = await showOrbiSheet<bool>(
    context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: SaveSearchSheet(spec: spec, editing: editing),
    ),
  );
  return ok ?? false;
}

class SaveSearchSheet extends StatefulWidget {
  const SaveSearchSheet({super.key, required this.spec, this.editing});
  final SearchSpec spec;
  final SavedSearch? editing;

  @override
  State<SaveSearchSheet> createState() => _SaveSearchSheetState();
}

class _SaveSearchSheetState extends State<SaveSearchSheet> {
  final _name = TextEditingController();
  late SearchSpec _spec = widget.spec;
  late bool _alerts = widget.editing?.alertsEnabled ?? false;
  late AlertFrequency _frequency =
      widget.editing?.frequency ?? AlertFrequency.daily;
  bool _initialised = false;
  String? _nameError;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final l = AppLocalizations.of(context);
    _name.text =
        widget.editing?.name ?? defaultSearchName(_spec, l, langOf(context));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      return setState(() => _nameError = l.ssNameRequired);
    }
    if (name.length > SavedSearchesCubit.maxNameLength) {
      return setState(
        () => _nameError = l.ssNameTooLong(SavedSearchesCubit.maxNameLength),
      );
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });
    final cubit = context.read<SavedSearchesCubit>();
    final editing = widget.editing;
    final ok = editing == null
        ? await cubit.saveSpec(
            _spec,
            name: name,
            alerts: _alerts,
            frequency: _frequency,
          )
        : await cubit.update(
            editing.id,
            spec: _spec,
            name: name,
            alerts: _alerts,
            frequency: _frequency,
          );
    if (!mounted) return;
    if (ok) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop(true);
      messenger?.showSnackBar(
        SnackBar(content: Text(editing == null ? l.ssSaved : l.ssUpdated)),
      );
      return;
    }
    setState(() => _saving = false);
    final f = cubit.state.actionFailure;
    if (f != null) showDataFailure(context, f);
  }

  /// What Explore shows right now, when there is a search to take.
  SearchSpec? _currentExplore(BuildContext context) {
    try {
      final s = context.read<SearchCubit>().currentSpec;
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = langOf(context);
    final parts = describeSpec(_spec, l, lang);
    final current = widget.editing == null ? null : _currentExplore(context);
    return OrbiSheetScaffold(
      title: widget.editing == null ? l.ssSaveSheetTitle : l.ssEditSheetTitle,
      footer: OrbiPrimaryButton(
        label: l.commonSave,
        expand: true,
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s4),
              child: Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s1,
                children: [for (final p in parts) OrbiStatusBadge(label: p)],
              ),
            ),
          if (current != null && current != _spec)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OrbiTextButton(
                label: l.ssUseCurrent,
                icon: Icons.sync_alt_rounded,
                onPressed: () => setState(() => _spec = current),
              ),
            ),
          OrbiTextField(
            label: l.ssNameLabel,
            hint: l.ssNameHint,
            controller: _name,
            errorText: _nameError,
            maxLength: SavedSearchesCubit.maxNameLength + 20,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpace.s4),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _alerts,
            onChanged: (v) => setState(() => _alerts = v),
            title: Text(l.ssAlertsLabel),
            subtitle: Text(l.ssAlertsHelp),
          ),
          if (_alerts) ...[
            const SizedBox(height: AppSpace.s2),
            OrbiFieldLabel(l.ssFrequencyLabel),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s1,
              children: [
                for (final f in AlertFrequency.values)
                  OrbiFilterChip(
                    label: frequencyLabel(f, l),
                    selected: _frequency == f,
                    onSelected: (_) => setState(() => _frequency = f),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
