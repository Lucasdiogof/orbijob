import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/orbi/orbi.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/continent.dart';
import '../../domain/entities/job_posting.dart';
import '../../domain/job_filters.dart';
import 'area_chips.dart';
import 'area_picker.dart';

/// Number of active filters, shown on the filters button.
int activeFilterCount(JobFilters f) =>
    f.workModes.length +
    (f.publishedWithinDays != null ? 1 : 0) +
    (f.onlyWithSalary ? 1 : 0) +
    (f.countryCode != null ? 1 : 0) +
    (f.continent != null ? 1 : 0) +
    (f.area != null ? 1 : 0) +
    (f.specialty != null ? 1 : 0);

String continentLabel(Continent k, AppLocalizations l) => switch (k) {
  Continent.europe => l.continentEurope,
  Continent.oceania => l.continentOceania,
  Continent.asia => l.continentAsia,
  Continent.africa => l.continentAfrica,
  Continent.northAmerica => l.continentNorthAmerica,
  Continent.southAmerica => l.continentSouthAmerica,
};

/// The grouped filters: region, work mode, publication date, salary and professional area. The same body is used in the mobile sheet
/// (changes are drafted until "Show results") and in the desktop sidebar (changes apply at once).
class FilterPanelBody extends StatelessWidget {
  const FilterPanelBody({
    super.key,
    required this.filters,
    required this.countries,
    required this.onChanged,
  });

  final JobFilters filters;

  /// ISO codes from the user's profile; their chips appear under the region chips when there are any.
  final List<String> countries;
  final ValueChanged<JobFilters> onChanged;

  static const _modes = [WorkMode.remote, WorkMode.hybrid, WorkMode.onsite];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    // An active country stays visible even if this account does not list it, so a filter is never on without a way to see and turn it off.
    final shownCountries = <String>[
      for (final code in countries) code.toUpperCase(),
      if (filters.countryCode != null &&
          !countries.map((x) => x.toUpperCase()).contains(filters.countryCode))
        filters.countryCode!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrbiFormSection(
          title: l.filterContinent,
          child: Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s1,
            children: [
              OrbiFilterChip(
                label: l.filterRegionAny,
                selected:
                    filters.continent == null && filters.countryCode == null,
                onSelected: (_) => onChanged(
                  filters.copyWith(clearContinent: true, clearCountry: true),
                ),
              ),
              for (final k in Continent.values)
                OrbiFilterChip(
                  label: continentLabel(k, l),
                  selected: filters.continent == k,
                  onSelected: (on) => onChanged(
                    on
                        ? filters.copyWith(continent: k)
                        : filters.copyWith(clearContinent: true),
                  ),
                ),
            ],
          ),
        ),
        if (shownCountries.isNotEmpty)
          OrbiFormSection(
            title: l.filterCountry,
            child: Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s1,
              children: [
                for (final code in shownCountries)
                  OrbiFilterChip(
                    label: code,
                    selected: filters.countryCode == code,
                    onSelected: (on) => onChanged(
                      on
                          ? filters.copyWith(countryCode: code)
                          : filters.copyWith(clearCountry: true),
                    ),
                  ),
              ],
            ),
          ),
        OrbiFormSection(
          title: l.filterWorkMode,
          child: Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s1,
            children: [
              for (final m in _modes)
                OrbiFilterChip(
                  label: switch (m) {
                    WorkMode.remote => l.workModeRemote,
                    WorkMode.hybrid => l.workModeHybrid,
                    _ => l.workModeOnsite,
                  },
                  selected: filters.workModes.contains(m),
                  onSelected: (on) => onChanged(
                    filters.copyWith(
                      workModes: on
                          ? {...filters.workModes, m}
                          : ({...filters.workModes}..remove(m)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        OrbiFormSection(
          title: l.filterPublished,
          child: Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s1,
            children: [
              for (final (days, label) in [
                (1, l.filterPublished1),
                (7, l.filterPublished7),
                (30, l.filterPublished30),
              ])
                OrbiFilterChip(
                  label: label,
                  selected: filters.publishedWithinDays == days,
                  onSelected: (on) => onChanged(
                    on
                        ? filters.copyWith(publishedWithinDays: days)
                        : filters.copyWith(clearPublished: true),
                  ),
                ),
            ],
          ),
        ),
        OrbiFormSection(
          title: l.filterSalary,
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l.filterWithSalary, style: context.text.bodyMedium),
            value: filters.onlyWithSalary,
            onChanged: (on) => onChanged(filters.copyWith(onlyWithSalary: on)),
          ),
        ),
        OrbiFormSection(
          title: l.filterArea,
          child: OrbiCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s2,
            ),
            onTap: () async {
              final picked = await showAreaPicker(
                context,
                area: filters.area,
                specialty: filters.specialty,
              );
              if (picked == null) return;
              onChanged(
                filters.copyWith(
                  area: picked.area,
                  clearArea: picked.area == null,
                  specialty: picked.specialty,
                  clearSpecialty: picked.specialty == null,
                ),
              );
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    filters.area == null
                        ? l.filterAreaAny
                        : areaLabel(filters.area!, l),
                    style: context.text.bodyMedium,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Mobile / tablet: the filters in a bottom sheet with a fixed footer. Changes are drafted and applied with "Show results".
Future<void> showExploreFilters(
  BuildContext context, {
  required JobFilters current,
  required List<String> countries,
  required ValueChanged<JobFilters> onApply,
}) {
  final l = AppLocalizations.of(context);
  var draft = current;
  return showOrbiSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => OrbiSheetScaffold(
        title: l.filtersTitle,
        body: FilterPanelBody(
          filters: draft,
          countries: countries,
          onChanged: (f) => setState(() => draft = f),
        ),
        footer: Row(
          children: [
            Expanded(
              child: OrbiSecondaryButton(
                label: l.filtersReset,
                onPressed: activeFilterCount(draft) == 0
                    ? null
                    : () => setState(() => draft = const JobFilters()),
              ),
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              flex: 2,
              child: OrbiPrimaryButton(
                label: l.filtersApply,
                onPressed: () {
                  onApply(draft);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The "filters" button of the search bar: the tune icon with a badge holding the number of active filters.
class FiltersButton extends StatelessWidget {
  const FiltersButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Semantics(
      button: true,
      label: count == 0 ? l.filtersButton : l.exploreFiltersActive(count),
      excludeSemantics: true,
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: l.filtersButton,
            icon: const Icon(Icons.tune_rounded),
            onPressed: onPressed,
          ),
          if (count > 0)
            Positioned(
              right: 4,
              top: 4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 18,
                    child: Center(
                      child: Text(
                        '$count',
                        style: context.text.labelSmall!.copyWith(
                          color: c.onPrimary,
                          fontSize: 11,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Desktop: the same filters as a persistent side panel; every change applies at once.
class FilterSidebar extends StatelessWidget {
  const FilterSidebar({
    super.key,
    required this.filters,
    required this.countries,
    required this.onChanged,
  });

  final JobFilters filters;
  final List<String> countries;
  final ValueChanged<JobFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      width: AppSize.filterSidebarWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: context.colors.hairline)),
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s5),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.filtersTitle, style: context.text.titleLarge),
                ),
                if (activeFilterCount(filters) > 0)
                  OrbiTextButton(
                    label: l.filtersReset,
                    onPressed: () => onChanged(const JobFilters()),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            FilterPanelBody(
              filters: filters,
              countries: countries,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
