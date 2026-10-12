import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/open_link.dart';
import '../../../../core/orbi/orbi.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/health_specialty.dart';
import '../../domain/specialty_portals.dart';
import '../cubit/specialties_cubit.dart';

String specialtyLabel(HealthSpecialty s, AppLocalizations l) => switch (s) {
  HealthSpecialty.physiotherapy => l.specPhysiotherapy,
  HealthSpecialty.pelvicPhysio => l.specPelvicPhysio,
  HealthSpecialty.nursing => l.specNursing,
  HealthSpecialty.medicine => l.specMedicine,
  HealthSpecialty.psychology => l.specPsychology,
  HealthSpecialty.occupationalTherapy => l.specOccupationalTherapy,
  HealthSpecialty.nutrition => l.specNutrition,
  HealthSpecialty.dentistry => l.specDentistry,
  HealthSpecialty.pharmacy => l.specPharmacy,
  HealthSpecialty.speechTherapy => l.specSpeechTherapy,
  HealthSpecialty.radiology => l.specRadiology,
  HealthSpecialty.hospitalManagement => l.specHospitalManagement,
};

/// Second row under the Health chip. Every specialty shows its real count, zero included, so a person sees at once
/// that the catalogue has, say, no pelvic physiotherapy job instead of discovering it after a tap; the "Specialised boards"
/// chip opens the external boards for the selected specialty. Pelvic physiotherapy is offered right after Physiotherapy.
class HealthSpecialtyChips extends StatelessWidget {
  const HealthSpecialtyChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final HealthSpecialty? selected;
  final ValueChanged<HealthSpecialty?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.read<SpecialtiesCubit>().ensureLoaded();
    return BlocBuilder<SpecialtiesCubit, SpecialtiesState>(
      builder: (context, s) {
        final chips = [
          OrbiFilterChip(
            label: l.specAll,
            icon: Icons.health_and_safety_outlined,
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final sp in HealthSpecialty.values)
            OrbiFilterChip(
              label: s.loaded
                  ? '${specialtyLabel(sp, l)} (${s.countOf(sp)})'
                  : specialtyLabel(sp, l),
              selected: selected == sp,
              onSelected: (_) => onSelected(selected == sp ? null : sp),
            ),
          OrbiFilterChip(
            label: l.portalsButton,
            icon: Icons.open_in_new,
            selected: false,
            onSelected: (_) => showSpecialtyPortals(context, selected),
          ),
        ];
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

/// The external boards for [specialty], as plain links, clearly apart from the catalogue.
Future<void> showSpecialtyPortals(
  BuildContext context,
  HealthSpecialty? specialty,
) {
  final l = AppLocalizations.of(context);
  final portals = portalsFor(specialty);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s4,
        ),
        children: [
          Text(l.portalsTitle, style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: AppSpace.s2),
          Text(l.portalsNote, style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: AppSpace.s2),
          for (final p in portals)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new),
              title: Text(p.name),
              subtitle: Text('${p.region} · ${Uri.parse(p.url).host}'),
              onTap: () => openExternalLink(p.url),
            ),
        ],
      ),
    ),
  );
}
