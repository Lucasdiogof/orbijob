import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design.dart';
import '../../core/widgets/app_filter_chip.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';
import '../search/presentation/cubit/search_cubit.dart';
import '../shell/shell_cubit.dart';
import 'recent_searches_cubit.dart';

/// Home: a way into search plus honest empty panels for what needs a profile and connected sources.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static List<(String, IconData)> areas(AppLocalizations l) => [
    (l.areaTechnology, Icons.code),
    (l.areaHealth, Icons.health_and_safety_outlined),
    (l.areaConstruction, Icons.construction),
    (l.areaEducation, Icons.school_outlined),
    (l.areaServices, Icons.handyman_outlined),
    (l.areaIndustry, Icons.precision_manufacturing_outlined),
    (l.areaTransport, Icons.local_shipping_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final panels = [
      _EmptyPanel(
        icon: Icons.auto_awesome_outlined,
        title: l.homeForYouEmptyTitle,
        body: l.homeForYouEmptyBody,
      ),
      _EmptyPanel(
        icon: Icons.public,
        title: l.interestCountriesEmptyTitle,
        body: l.interestCountriesEmptyBody,
      ),
      _EmptyPanel(
        icon: Icons.assignment_outlined,
        title: l.homeApplicationsEmptyTitle,
        body: l.homeApplicationsEmptyBody,
      ),
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
        child: ListView(
          padding: EdgeInsets.all(wide ? AppSpace.s6 : AppSpace.s4),
          children: [
            Semantics(
              header: true,
              child: Text(l.homeTitle, style: context.text.headlineMedium),
            ),
            const SizedBox(height: AppSpace.s4),
            AppSearchField(
              hint: l.homeSearchHint,
              readOnly: true,
              onTap: context.read<ShellCubit>().openSearch,
            ),
            const SizedBox(height: AppSpace.s6),
            BlocBuilder<RecentSearchesCubit, List<String>>(
              builder: (context, recent) => recent.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: l.recentSearchesTitle,
                            action: TextButton(
                              onPressed: context
                                  .read<RecentSearchesCubit>()
                                  .clear,
                              child: Text(l.recentSearchesClear),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s3),
                          Wrap(
                            spacing: AppSpace.s2,
                            runSpacing: AppSpace.s1,
                            children: [
                              for (final q in recent)
                                AppFilterChip(
                                  label: q,
                                  icon: Icons.history,
                                  selected: false,
                                  onSelected: (_) {
                                    context.read<SearchCubit>().search(q);
                                    context.read<ShellCubit>().goTo(
                                      ShellCubit.explore,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            SectionHeader(title: l.homeAreasTitle),
            const SizedBox(height: AppSpace.s3),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s1,
              children: [
                for (final (label, icon) in areas(l))
                  AppFilterChip(
                    label: label,
                    icon: icon,
                    selected: false,
                    onSelected: (_) {
                      context.read<SearchCubit>().search(label);
                      context.read<ShellCubit>().goTo(ShellCubit.explore);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s6),
            SectionHeader(title: l.homeForYouTitle),
            const SizedBox(height: AppSpace.s3),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in panels)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpace.s3),
                        child: p,
                      ),
                    ),
                ],
              )
            else
              for (final p in panels) ...[
                p,
                const SizedBox(height: AppSpace.s3),
              ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: c.primary),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    body,
                    style: context.text.bodyMedium!.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
