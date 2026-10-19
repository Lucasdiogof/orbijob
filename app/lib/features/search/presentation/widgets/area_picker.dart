import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/orbi/orbi.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/health_specialty.dart';
import '../../domain/job_area.dart';
import '../cubit/areas_cubit.dart';
import '../cubit/specialties_cubit.dart';
import 'area_chips.dart';
import 'health_specialty_chips.dart';

/// The result of the picker: an area and, inside Health, an optional specialty. `area == null` means "all areas".
class AreaPick {
  const AreaPick(this.area, [this.specialty]);
  final JobArea? area;
  final HealthSpecialty? specialty;
}

/// Hierarchical picker: all areas with their real counts and, under Health, the specialties
/// (Physiotherapy, then Pelvic physiotherapy one step in, and so on). Returns null when dismissed.
Future<AreaPick?> showAreaPicker(
  BuildContext context, {
  JobArea? area,
  HealthSpecialty? specialty,
}) => showOrbiSheet<AreaPick>(
  context,
  builder: (ctx) => _AreaPickerSheet(area: area, specialty: specialty),
);

class _AreaPickerSheet extends StatefulWidget {
  const _AreaPickerSheet({this.area, this.specialty});
  final JobArea? area;
  final HealthSpecialty? specialty;

  @override
  State<_AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends State<_AreaPickerSheet> {
  late bool _healthOpen = widget.area == JobArea.health;

  @override
  void initState() {
    super.initState();
    if (_healthOpen) context.read<SpecialtiesCubit>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OrbiSheetScaffold(
      title: l.areaPickerTitle,
      body: BlocBuilder<AreasCubit, AreasState>(
        builder: (context, a) => Column(
          children: [
            _Row(
              icon: Icons.apps_rounded,
              label: l.filterAreaAny,
              selected: widget.area == null,
              onTap: () => Navigator.of(context).pop(const AreaPick(null)),
            ),
            for (final area in a.available) ...[
              _Row(
                icon: areaIcon(area),
                label: areaLabel(area, l),
                trailing: l.areaJobsCount(a.counts[area] ?? 0),
                selected: widget.area == area && widget.specialty == null,
                expandable: area == JobArea.health,
                expanded: area == JobArea.health && _healthOpen,
                onTap: () {
                  if (area == JobArea.health) {
                    setState(() => _healthOpen = !_healthOpen);
                    if (_healthOpen) {
                      context.read<SpecialtiesCubit>().ensureLoaded();
                    }
                  } else {
                    Navigator.of(context).pop(AreaPick(area));
                  }
                },
              ),
              if (area == JobArea.health && _healthOpen)
                BlocBuilder<SpecialtiesCubit, SpecialtiesState>(
                  builder: (context, s) => Padding(
                    padding: const EdgeInsets.only(left: AppSpace.s6),
                    child: Column(
                      children: [
                        _Row(
                          icon: Icons.health_and_safety_outlined,
                          label: l.areaAll,
                          selected:
                              widget.area == JobArea.health &&
                              widget.specialty == null,
                          dense: true,
                          onTap: () =>
                              Navigator.of(context)
                                  .pop(const AreaPick(JobArea.health)),
                        ),
                        for (final sp in HealthSpecialty.values)
                          Padding(
                            // pelvic physiotherapy refines physiotherapy: drawn one step in
                            padding: EdgeInsets.only(
                              left: sp == HealthSpecialty.pelvicPhysio
                                  ? AppSpace.s5
                                  : 0,
                            ),
                            child: _Row(
                              icon: sp == HealthSpecialty.pelvicPhysio
                                  ? Icons.subdirectory_arrow_right_rounded
                                  : Icons.circle,
                              iconSize: sp == HealthSpecialty.pelvicPhysio
                                  ? 20
                                  : 6,
                              label: specialtyLabel(sp, l),
                              trailing: s.loaded
                                  ? l.areaJobsCount(s.countOf(sp))
                                  : null,
                              selected: widget.specialty == sp,
                              dense: true,
                              onTap: () =>
                                  Navigator.of(context)
                                      .pop(AreaPick(JobArea.health, sp)),
                            ),
                          ),
                        _Row(
                          icon: Icons.open_in_new,
                          label: l.portalsButton,
                          dense: true,
                          onTap: () =>
                              showSpecialtyPortals(context, widget.specialty),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.selected = false,
    this.expandable = false,
    this.expanded = false,
    this.dense = false,
    this.iconSize = 22,
  });

  final IconData icon;
  final double iconSize;
  final String label;
  final String? trailing;
  final bool selected;
  final bool expandable;
  final bool expanded;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: trailing == null ? label : '$label, $trailing',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: dense ? 44 : 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: selected ? c.primary : c.muted,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Text(
                    label,
                    style: context.text.bodyMedium!.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(trailing!, style: context.metadataStyle),
                if (expandable)
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: c.muted,
                  )
                else if (selected)
                  Icon(Icons.check_rounded, color: c.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
