import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design.dart';
import '../../core/format/country_names.dart';
import '../../core/format/job_format.dart';
import '../../core/orbi/orbi.dart';
import '../../l10n/app_localizations.dart';
import '../browser/open_in_app.dart';
import '../search/domain/entities/job_posting.dart';
import 'compare_cubit.dart';

/// One line of the comparison: what is compared and, for each job in the same order, what the listing states (null = it does not say).
class CompareRow {
  const CompareRow(this.label, this.values);
  final String label;
  final List<String?> values;

  /// More than one distinct stated value: worth the eye.
  bool get differs {
    final stated = values.whereType<String>().toSet();
    return stated.length > 1 || (stated.isNotEmpty && values.contains(null));
  }
}

/// What can honestly be compared. Every value is the listing's own: a missing one stays missing (null), never estimated, defaulted or copied
/// from a similar job. Who may apply is read from the explicit restriction list only: a job's location is not its eligibility.
List<CompareRow> comparisonRows(
  List<JobPosting> jobs,
  AppLocalizations l, {
  DateTime? now,
}) {
  final lang = l.localeName.split('_').first;
  final at = now ?? DateTime.now();
  String? text(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
  String? eligibility(JobPosting j) {
    final tokens = [
      for (final t in j.geoRestrictions)
        if (t.trim().isNotEmpty) t.trim(),
    ];
    if (tokens.isEmpty) return null;
    final rest = tokens.where((t) => t.toLowerCase() != 'anywhere').toList();
    if (rest.isEmpty) return l.cpEligibilityAnywhere;
    final names = [
      for (final t in rest) countryName(t, lang) ?? regionName(t, lang) ?? t,
    ];
    return l.cpEligibilityRestricted(names.join(', '));
  }

  final rows = <CompareRow>[
    CompareRow(l.cpRowCompany, [for (final j in jobs) text(j.company)]),
    CompareRow(l.cpRowPlace, [for (final j in jobs) placeLabel(j, l)]),
    CompareRow(l.cpRowMode, [
      for (final j in jobs)
        j.workMode == WorkMode.unspecified
            ? null
            : workModeLabel(j.workMode, l),
    ]),
    CompareRow(l.cpRowContract, [for (final j in jobs) text(j.contractType)]),
    CompareRow(l.cpRowSalary, [for (final j in jobs) formatSalary(j, l)]),
    CompareRow(l.cpRowPublished, [
      for (final j in jobs) formatPublished(j.publishedAt, at, l),
    ]),
    CompareRow(l.cpRowEligibility, [for (final j in jobs) eligibility(j)]),
    CompareRow(l.cpRowLanguage, [
      for (final j in jobs) nativeLanguageName(text(j.language)),
    ]),
    // requirements and benefits have no structured field in any source; skills only where the source lists them
    CompareRow(l.cpRowSkills, [
      for (final j in jobs) j.skills.isEmpty ? null : j.skills.join(', '),
    ]),
    CompareRow(l.cpRowSource, [for (final j in jobs) text(j.sourceName)]),
  ];
  return rows;
}

/// True when two or more of the compared jobs state a salary and they are not in one currency and one period.
bool salariesNotComparable(List<JobPosting> jobs) {
  final stated = [
    for (final j in jobs)
      if (j.salaryMin != null || j.salaryMax != null)
        '${j.salaryCurrency}/${j.salaryPeriod?.name}',
  ];
  return stated.length >= 2 && stated.toSet().length > 1;
}

/// A bar over the navigation while jobs are picked: how many, a way to clear and the button that opens the comparison.
class CompareBar extends StatelessWidget {
  const CompareBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return BlocBuilder<CompareCubit, List<JobPosting>>(
      builder: (context, picked) {
        if (picked.isEmpty) return const SizedBox.shrink();
        return Material(
          color: c.surface,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.hairline)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s2,
              ),
              // A Wrap, not a Row: with large text the buttons drop to a second line instead of overflowing.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: AppSpace.s1,
                children: [
                  Text(l.cpBar(picked.length), style: context.text.labelLarge),
                  OrbiTextButton(
                    label: l.cpClear,
                    onPressed: context.read<CompareCubit>().clear,
                  ),
                  OrbiPrimaryButton(
                    label: l.cpCompare,
                    icon: Icons.compare_arrows_rounded,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider.value(
                          value: context.read<CompareCubit>(),
                          child: const ComparePage(),
                        ),
                      ),
                    ),
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

/// Up to three jobs side by side. Wide windows get a table; narrow ones get one block per attribute, so nothing needs sideways scrolling.
class ComparePage extends StatelessWidget {
  const ComparePage({super.key, this.now});
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.cpTitle)),
      body: BlocBuilder<CompareCubit, List<JobPosting>>(
        builder: (context, jobs) {
          if (jobs.length < 2) {
            return OrbiEmptyState(
              icon: Icons.compare_arrows_rounded,
              title: l.cpTitle,
              body: l.cpNeedTwo,
              kind: OrbiStateKind.info,
            );
          }
          final rows = comparisonRows(jobs, l, now: now);
          return LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 680;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1100 : 560),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    children: [
                      Text(l.cpHint, style: context.metadataStyle),
                      const SizedBox(height: AppSpace.s3),
                      _Heads(jobs: jobs, wide: wide),
                      const SizedBox(height: AppSpace.s3),
                      if (wide)
                        _Table(jobs: jobs, rows: rows)
                      else
                        _Stacked(jobs: jobs, rows: rows),
                      if (salariesNotComparable(jobs)) ...[
                        const SizedBox(height: AppSpace.s3),
                        Text(l.cpSalaryNote, style: context.metadataStyle),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Heads extends StatelessWidget {
  const _Heads({required this.jobs, required this.wide});
  final List<JobPosting> jobs;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cards = [
      for (final (i, j) in jobs.indexed)
        OrbiCard(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      wide ? j.title : '${i + 1}. ${j.title}',
                      style: context.text.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: l.cpRemoveOne(j.title),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => context.read<CompareCubit>().remove(j),
                  ),
                ],
              ),
              if (j.company.isNotEmpty)
                Text(j.company, style: context.metadataStyle),
              if (j.originalUrl.isNotEmpty)
                OrbiTextButton(
                  label: l.cpOpenListing,
                  icon: Icons.open_in_new,
                  onPressed: () => openInApp(context, j.originalUrl, job: j),
                ),
            ],
          ),
        ),
    ];
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: _labelWidth),
          for (final c in cards)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpace.s2),
                child: c,
              ),
            ),
        ],
      );
    }
    return Column(
      children: [
        for (final c in cards)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: c,
          ),
      ],
    );
  }
}

const double _labelWidth = 150;

class _Table extends StatelessWidget {
  const _Table({required this.jobs, required this.rows});
  final List<JobPosting> jobs;
  final List<CompareRow> rows;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Column(
      children: [
        for (final r in rows)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.hairline)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Text(r.label, style: context.text.labelLarge),
                  ),
                  for (final v in r.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpace.s2),
                        child: Text(
                          v ?? l.cpNotStated,
                          style: v == null
                              ? context.metadataStyle
                              : (r.differs
                                    ? context.text.bodyMedium!.copyWith(
                                        fontWeight: FontWeight.w600,
                                      )
                                    : context.text.bodyMedium),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Stacked extends StatelessWidget {
  const _Stacked({required this.jobs, required this.rows});
  final List<JobPosting> jobs;
  final List<CompareRow> rows;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in rows)
          OrbiCard(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.label, style: context.text.labelLarge),
                const SizedBox(height: AppSpace.s1),
                for (var i = 0; i < jobs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${i + 1}. ',
                            style: context.metadataStyle,
                          ),
                          TextSpan(
                            text: r.values[i] ?? l.cpNotStated,
                            style: r.values[i] == null
                                ? context.metadataStyle.copyWith(color: c.muted)
                                : (r.differs
                                      ? context.text.bodyMedium!.copyWith(
                                          fontWeight: FontWeight.w600,
                                        )
                                      : context.text.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ].expand((w) => [w, const SizedBox(height: AppSpace.s2)]).toList(),
    );
  }
}
