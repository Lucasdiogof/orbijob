import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/load_status.dart';
import '../../../core/design/design.dart';
import '../../../core/locale_cubit.dart';
import '../../../core/theme_cubit.dart';
import '../../../core/widgets/data_state_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/app_localizations.dart';
import 'preferences_cubit.dart';
import 'saved_searches_cubit.dart';

/// Appearance, language, countries of interest and saved searches. Theme and language apply at once on this
/// device; they are also kept in the account when the preferences were loaded from it.
class PreferencesSection extends StatefulWidget {
  const PreferencesSection({super.key});
  @override
  State<PreferencesSection> createState() => _PreferencesSectionState();
}

class _PreferencesSectionState extends State<PreferencesSection> {
  final _country = TextEditingController();

  @override
  void dispose() {
    _country.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final ok = await context.read<PreferencesCubit>().addCountry(_country.text);
    if (ok) _country.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = context.text.bodySmall!.copyWith(color: context.colors.muted);
    return BlocConsumer<PreferencesCubit, PreferencesState>(
      listenWhen: (a, b) => a.actionTick != b.actionTick,
      listener: (context, s) {
        if (s.actionFailure != null) showDataFailure(context, s.actionFailure!);
      },
      builder: (context, s) {
        final theme = context.watch<ThemeCubit>().state;
        final locale = context.watch<LocaleCubit>().state?.languageCode;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l.appearanceTitle),
            const SizedBox(height: AppSpace.s3),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: true,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_outlined),
                  label: Text(l.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(l.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(l.themeDark),
                ),
              ],
              selected: {theme},
              onSelectionChanged: (v) {
                context.read<ThemeCubit>().select(v.first);
                context.read<PreferencesCubit>().setTheme(v.first.name);
              },
            ),
            const SizedBox(height: AppSpace.s4),
            Text(l.languageTitle, style: context.text.titleSmall),
            const SizedBox(height: AppSpace.s2),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: '', label: Text(l.languageSystem)),
                ButtonSegment(value: 'pt', label: Text(l.languagePt)),
                ButtonSegment(value: 'en', label: Text(l.languageEn)),
                ButtonSegment(value: 'es', label: Text(l.languageEs)),
              ],
              selected: {locale ?? ''},
              onSelectionChanged: (v) {
                final code = v.first.isEmpty ? null : v.first;
                context.read<LocaleCubit>().select(code);
                context.read<PreferencesCubit>().setLocale(code);
              },
            ),
            if (!s.synced) ...[
              const SizedBox(height: AppSpace.s2),
              Text(l.preferencesLocalOnly, style: muted),
            ],
            if (s.synced) ...[
              const SizedBox(height: AppSpace.s6),
              SectionHeader(title: l.countriesTitle),
              const SizedBox(height: AppSpace.s3),
              if (s.prefs.countriesOfInterest.isEmpty)
                Text(l.countriesEmpty, style: muted),
              Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                children: [
                  for (final c in s.prefs.countriesOfInterest)
                    InputChip(
                      label: Text(c),
                      deleteButtonTooltipMessage: l.countriesRemove(c),
                      onDeleted: () =>
                          context.read<PreferencesCubit>().removeCountry(c),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _country,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 2,
                      decoration: InputDecoration(
                        labelText: l.countriesHint,
                        helperText: l.countriesInvalid,
                        counterText: '',
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  IconButton(
                    tooltip: l.commonAdd,
                    icon: const Icon(Icons.add),
                    onPressed: s.saving ? null : _add,
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpace.s6),
            const SavedSearchesSection(),
          ],
        );
      },
    );
  }
}

class SavedSearchesSection extends StatelessWidget {
  const SavedSearchesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = context.text.bodySmall!.copyWith(color: context.colors.muted);
    return BlocConsumer<SavedSearchesCubit, SavedSearchesState>(
      listenWhen: (a, b) => a.actionTick != b.actionTick,
      listener: (context, s) {
        if (s.actionFailure != null) showDataFailure(context, s.actionFailure!);
      },
      builder: (context, s) {
        Widget body;
        if (s.status == LoadStatus.loading) {
          body = const LinearProgressIndicator();
        } else if (s.status == LoadStatus.failure) {
          body = Text(dataFailureText(l, s.failure!), style: muted);
        } else if (s.items.isEmpty) {
          body = Text(l.savedSearchesNote, style: muted);
        } else {
          body = Column(
            children: [
              for (final q in s.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bookmark_border),
                  title: Text(SavedSearchesCubit.termOf(q)),
                  subtitle: SavedSearchesCubit.countryOf(q) == null
                      ? null
                      : Text(SavedSearchesCubit.countryOf(q)!),
                  trailing: IconButton(
                    tooltip: l.savedSearchRemove(SavedSearchesCubit.termOf(q)),
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        context.read<SavedSearchesCubit>().remove(q.id),
                  ),
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l.savedSearchesTitle),
            const SizedBox(height: AppSpace.s3),
            body,
          ],
        );
      },
    );
  }
}
