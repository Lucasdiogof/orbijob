import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/orbi/orbi.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/job_area.dart';
import '../cubit/areas_cubit.dart';
import 'area_chips.dart';

/// Professional areas as compact tiles: an icon on a soft surface, the area name and the real number of open jobs.
/// Only areas that have jobs right now are listed (counts come from the catalogue, never invented). [maxItems] limits the grid
/// (Home shows the busiest ones and links to the full list).
class AreaGrid extends StatelessWidget {
  const AreaGrid({
    super.key,
    required this.onSelected,
    this.maxItems,
    this.selected,
  });

  final ValueChanged<JobArea> onSelected;
  final int? maxItems;
  final JobArea? selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<AreasCubit, AreasState>(
      builder: (context, s) {
        final areas = [...s.available]
          ..sort((a, b) => (s.counts[b] ?? 0).compareTo(s.counts[a] ?? 0));
        if (areas.isEmpty) return const SizedBox.shrink();
        final shown = maxItems == null ? areas : areas.take(maxItems!).toList();
        return LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 900
                ? 4
                : box.maxWidth >= 560
                ? 3
                : 2;
            final gap = AppSpace.s3;
            final w = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final a in shown)
                  SizedBox(
                    width: w,
                    child: _AreaTile(
                      area: a,
                      title: areaLabel(a, l),
                      count: l.areaJobsCount(s.counts[a] ?? 0),
                      selected: selected == a,
                      onTap: () => onSelected(a),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({
    required this.area,
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final JobArea area;
  final String title;
  final String count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$title, $count',
      excludeSemantics: true,
      onTap: onTap,
      child: OrbiCard(
        selected: selected,
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Icon(
                  areaIcon(area),
                  size: 22,
                  color: c.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.labelLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(count, style: context.metadataStyle, maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The full list of areas, one screen of its own.
class AllAreasPage extends StatelessWidget {
  const AllAreasPage({super.key, required this.onSelected});

  final ValueChanged<JobArea> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.areasPageTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: [
              Text(
                l.areasPageBody,
                style: context.text.bodyMedium!.copyWith(
                  color: context.colors.muted,
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              AreaGrid(
                onSelected: (a) {
                  Navigator.of(context).pop();
                  onSelected(a);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
