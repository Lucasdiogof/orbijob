import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/format/job_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/job_posting.dart';
import '../../domain/job_filters.dart';

/// Number of active filters, shown on the toggle button.
int activeFilterCount(JobFilters f) =>
    f.workModes.length +
    (f.publishedWithinDays != null ? 1 : 0) +
    (f.onlyWithSalary ? 1 : 0) +
    (f.countryCode != null ? 1 : 0);

/// Filters the catalogue can answer: work mode, publication date, "has a salary" and, when the profile lists
/// countries of interest, one of those countries. Nothing here changes by itself: every chip reports through [onChanged].
class SearchFiltersPanel extends StatelessWidget {
  const SearchFiltersPanel({
    super.key,
    required this.filters,
    required this.countries,
    required this.onChanged,
  });

  final JobFilters filters;

  /// ISO codes from the user's profile; the country filter is not drawn when empty.
  final List<String> countries;
  final ValueChanged<JobFilters> onChanged;

  static const _modes = [WorkMode.remote, WorkMode.hybrid, WorkMode.onsite];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.text;
    final c = context.colors;
    Widget group(String title, List<Widget> chips) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.labelMedium!.copyWith(color: c.muted)),
        const SizedBox(height: AppSpace.s1),
        Wrap(spacing: AppSpace.s2, runSpacing: AppSpace.s1, children: chips),
      ],
    );

    // An active country stays visible even if this account does not list it (e.g. after a switch of account), so
    // a filter can never be on without a way to see and turn it off.
    final shownCountries = <String>[
      for (final c in countries) c.toUpperCase(),
      if (filters.countryCode != null &&
          !countries.map((c) => c.toUpperCase()).contains(filters.countryCode))
        filters.countryCode!,
    ];

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            group(l.filterWorkMode, [
              for (final m in _modes)
                AppFilterChip(
                  label: workModeLabel(m, l),
                  selected: filters.workModes.contains(m),
                  onSelected: (on) => onChanged(
                    filters.copyWith(
                      workModes: on
                          ? {...filters.workModes, m}
                          : ({...filters.workModes}..remove(m)),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: AppSpace.s3),
            group(l.filterPublished, [
              for (final (days, label) in [
                (1, l.filterPublished1),
                (7, l.filterPublished7),
                (30, l.filterPublished30),
              ])
                AppFilterChip(
                  label: label,
                  selected: filters.publishedWithinDays == days,
                  onSelected: (on) => onChanged(
                    on
                        ? filters.copyWith(publishedWithinDays: days)
                        : filters.copyWith(clearPublished: true),
                  ),
                ),
            ]),
            const SizedBox(height: AppSpace.s3),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s1,
              children: [
                AppFilterChip(
                  label: l.filterWithSalary,
                  selected: filters.onlyWithSalary,
                  onSelected: (on) =>
                      onChanged(filters.copyWith(onlyWithSalary: on)),
                ),
              ],
            ),
            if (shownCountries.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s3),
              group(l.filterCountry, [
                for (final code in shownCountries)
                  AppFilterChip(
                    label: code.toUpperCase(),
                    selected: filters.countryCode == code.toUpperCase(),
                    onSelected: (on) => onChanged(
                      on
                          ? filters.copyWith(countryCode: code.toUpperCase())
                          : filters.copyWith(clearCountry: true),
                    ),
                  ),
              ]),
            ],
            if (filters.isActive) ...[
              const SizedBox(height: AppSpace.s2),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: l.filtersClear,
                  icon: Icons.filter_alt_off_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => onChanged(const JobFilters()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
