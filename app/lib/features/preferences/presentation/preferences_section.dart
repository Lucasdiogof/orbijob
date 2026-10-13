import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/locale_cubit.dart';
import '../../../core/orbi/orbi.dart';
import '../../../core/theme_cubit.dart';
import '../../../core/widgets/data_state_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../translation/translation_cubit.dart';
import 'preferences_cubit.dart';
import '../../searches/presentation/saved_searches_page.dart';

/// Language and appearance. Both apply at once on this device and are also kept in the account when the preferences
/// were loaded from it. The language is a list in a sheet (radio), never a segmented control: "Português" and the
/// other names must never be squeezed or wrapped.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  static String languageName(AppLocalizations l, String? code) =>
      switch (code) {
        'pt' => l.languagePt,
        'en' => l.languageEn,
        'es' => l.languageEs,
        _ => l.languageSystem,
      };

  Future<void> _chooseLanguage(BuildContext context, String? current) async {
    final l = AppLocalizations.of(context);
    final locales = context.read<LocaleCubit>();
    final prefs = context.read<PreferencesCubit>();
    await showOrbiSheet<void>(
      context,
      builder: (ctx) => OrbiSheetScaffold(
        title: l.languageTitle,
        body: RadioGroup<String>(
          groupValue: current ?? '',
          onChanged: (v) {
            final code = (v == null || v.isEmpty) ? null : v;
            locales.select(code);
            prefs.setLocale(code);
            Navigator.of(ctx).pop();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s2),
                child: Text(
                  l.languageChooseHint,
                  style: ctx.text.bodySmall!.copyWith(color: ctx.colors.muted),
                ),
              ),
              for (final (code, name) in [
                ('', l.languageSystem),
                ('pt', l.languagePt),
                ('en', l.languageEn),
                ('es', l.languageEs),
              ])
                RadioListTile<String>(
                  value: code,
                  contentPadding: EdgeInsets.zero,
                  title: Text(name, style: ctx.text.bodyLarge),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final theme = context.watch<ThemeCubit>().state;
    final locale = context.watch<LocaleCubit>().state?.languageCode;
    final synced = context.select<PreferencesCubit, bool>(
      (p) => p.state.synced,
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        OrbiSectionHeader(title: l.languageTitle),
        const SizedBox(height: AppSpace.s3),
        OrbiCard(
          onTap: () => _chooseLanguage(context, locale),
          child: Row(
            children: [
              Icon(Icons.language_rounded, color: c.muted),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Text(
                  languageName(l, locale),
                  style: context.text.bodyLarge,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.muted),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s6),
        OrbiSectionHeader(title: l.appearanceTitle),
        const SizedBox(height: AppSpace.s3),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
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
        const SizedBox(height: AppSpace.s6),
        OrbiSectionHeader(title: l.translationSettingsTitle),
        const SizedBox(height: AppSpace.s3),
        BlocBuilder<TranslationCubit, TranslationState>(
          builder: (context, tr) => OrbiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.translationSettingsSwitch),
                  value: tr.enabled,
                  onChanged: (v) =>
                      context.read<TranslationCubit>().setEnabled(v),
                ),
                Text(
                  l.translationSettingsBody,
                  style: context.text.bodySmall!.copyWith(color: c.muted),
                ),
                const SizedBox(height: AppSpace.s3),
                OrbiTextButton(
                  label: l.translationClearCache,
                  onPressed: () async {
                    await context.read<TranslationCubit>().clearSaved();
                    if (context.mounted) {
                      showOrbiSnackBar(
                        context,
                        l.translationCacheCleared,
                        kind: OrbiSnackKind.success,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        if (!synced) ...[
          const SizedBox(height: AppSpace.s3),
          Text(
            l.preferencesLocalOnly,
            style: context.text.bodySmall!.copyWith(color: c.muted),
          ),
        ],
      ],
    );
  }
}

/// Countries of interest and saved searches (account only).
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
      builder: (context, s) => ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          if (s.synced) ...[
            OrbiSectionHeader(title: l.countriesTitle),
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
            const SizedBox(height: AppSpace.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: OrbiTextField(
                    label: l.countriesHint,
                    controller: _country,
                    helper: l.countriesInvalid,
                    maxLength: 2,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                IconButton(
                  tooltip: l.commonAdd,
                  icon: const Icon(Icons.add_rounded),
                  onPressed: s.saving ? null : _add,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s6),
          ] else ...[
            Text(l.preferencesLocalOnly, style: muted),
            const SizedBox(height: AppSpace.s6),
          ],
          const SavedSearchesSection(),
        ],
      ),
    );
  }
}

class SavedSearchesSection extends StatelessWidget {
  const SavedSearchesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrbiSectionHeader(title: l.savedSearchesTitle),
        const SizedBox(height: AppSpace.s2),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bookmarks_outlined),
          title: Text(l.ssTitle),
          subtitle: Text(l.ssSubtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SavedSearchesPage()),
          ),
        ),
      ],
    );
  }
}
