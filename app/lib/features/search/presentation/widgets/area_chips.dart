import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/job_area.dart';
import '../cubit/areas_cubit.dart';

String areaLabel(JobArea a, AppLocalizations l) => switch (a) {
  JobArea.technology => l.areaTechnology,
  JobArea.data => l.areaData,
  JobArea.design => l.areaDesign,
  JobArea.product => l.areaProduct,
  JobArea.sales => l.areaSales,
  JobArea.marketing => l.areaMarketing,
  JobArea.support => l.areaSupport,
  JobArea.finance => l.areaFinance,
  JobArea.people => l.areaPeople,
  JobArea.health => l.areaHealth,
  JobArea.education => l.areaEducation,
  JobArea.hospitality => l.areaHospitality,
  JobArea.logistics => l.areaTransport,
  JobArea.construction => l.areaConstruction,
  JobArea.industry => l.areaIndustry,
  JobArea.services => l.areaServices,
  JobArea.public => l.areaPublic,
};

IconData areaIcon(JobArea a) => switch (a) {
  JobArea.technology => Icons.code,
  JobArea.data => Icons.insights_outlined,
  JobArea.design => Icons.brush_outlined,
  JobArea.product => Icons.view_kanban_outlined,
  JobArea.sales => Icons.trending_up,
  JobArea.marketing => Icons.campaign_outlined,
  JobArea.support => Icons.support_agent,
  JobArea.finance => Icons.account_balance_outlined,
  JobArea.people => Icons.groups_outlined,
  JobArea.health => Icons.health_and_safety_outlined,
  JobArea.education => Icons.school_outlined,
  JobArea.hospitality => Icons.hotel_outlined,
  JobArea.logistics => Icons.local_shipping_outlined,
  JobArea.construction => Icons.construction,
  JobArea.industry => Icons.precision_manufacturing_outlined,
  JobArea.services => Icons.handyman_outlined,
  JobArea.public => Icons.account_balance,
};

/// The professional areas that have open jobs right now, as chips ("Technology (185)"). Nothing is drawn while the counts
/// load or when none is available, so a chip never leads to an empty list. [selected] marks the active area.
class AreaChips extends StatelessWidget {
  const AreaChips({
    super.key,
    required this.onSelected,
    this.selected,
    this.scrollable = false,
    this.showAll = false,
  });

  final ValueChanged<JobArea?> onSelected;
  final JobArea? selected;

  /// One horizontally scrolling row (Explore) instead of a wrapping block (Home).
  final bool scrollable;

  /// Adds a leading "All areas" chip that reports null.
  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<AreasCubit, AreasState>(
      builder: (context, s) {
        final available = s.available;
        if (available.isEmpty) return const SizedBox.shrink();
        final chips = [
          if (showAll)
            AppFilterChip(
              label: l.areaAll,
              icon: Icons.apps,
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          for (final a in available)
            AppFilterChip(
              label: '${areaLabel(a, l)} (${s.counts[a]})',
              icon: areaIcon(a),
              selected: selected == a,
              onSelected: (_) => onSelected(selected == a && showAll ? null : a),
            ),
        ];
        if (!scrollable) {
          return Wrap(spacing: AppSpace.s2, runSpacing: AppSpace.s1, children: chips);
        }
        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s2),
            itemBuilder: (_, i) => Center(child: chips[i]),
          ),
        );
      },
    );
  }
}
