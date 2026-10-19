import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/data_failure.dart';
import '../../../../core/data/load_status.dart';
import '../../../../core/design/design.dart';
import '../../../../core/orbi/orbi.dart';
import '../../../../core/widgets/data_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/professional_profile.dart';
import '../profile_cubit.dart';
import '../resume_import_page.dart';
import '../../domain/pdf_picker.dart';
import '../../../../core/di/injector.dart';
import 'profile_forms.dart';

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s3),
    child: OrbiCard(child: child),
  );
}

/// Professional profile + experience + education, driven by [ProfileCubit].
class ProfileSections extends StatelessWidget {
  const ProfileSections({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocConsumer<ProfileCubit, ProfileState>(
      listenWhen: (a, b) => a.actionTick != b.actionTick,
      listener: (context, s) {
        if (s.actionFailure != null) showDataFailure(context, s.actionFailure!);
      },
      builder: (context, s) {
        Widget body;
        if (s.status == LoadStatus.loading) {
          body = const OrbiSkeletonList(count: 2, shrinkWrap: true);
        } else if (s.status == LoadStatus.failure) {
          body = SizedBox(
            height: 380,
            child: DataFailureView(
              kind: s.failure!,
              onRetry: () => context.read<ProfileCubit>().load(),
            ),
          );
        } else if (s.profile == null) {
          body = _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.profileCreateTitle, style: context.text.titleSmall),
                const SizedBox(height: AppSpace.s1),
                Text(
                  l.profileCreateBody,
                  style: context.text.bodyMedium!.copyWith(
                    color: context.colors.muted,
                  ),
                ),
                const SizedBox(height: AppSpace.s3),
                OrbiPrimaryButton(
                  label: l.profileCreateAction,
                  onPressed: () =>
                      openProfileForm(context, const ProfileFormPage()),
                ),
                const SizedBox(height: AppSpace.s2),
                OrbiSecondaryButton(
                  label: l.resumeImportStart,
                  icon: Icons.upload_file_outlined,
                  onPressed: () async {
                    PickedPdf? picked;
                    try {
                      picked = await sl<PdfPicker>().pick();
                    } catch (e) {
                      if (context.mounted) {
                        showDataFailure(context, mapDataError(e));
                      }
                      return;
                    }
                    if (picked != null && context.mounted) {
                      await startResumeImport(context, picked.bytes);
                    }
                  },
                ),
              ],
            ),
          );
        } else {
          final p = s.profile!;
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Reveal(child: _ProfileCard(p)),
              const SizedBox(height: AppSpace.s6),
              Reveal(index: 1, child: _ExperienceList(p, s.experiences)),
              const SizedBox(height: AppSpace.s6),
              Reveal(index: 2, child: _EducationList(p, s.education)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [body],
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard(this.p);
  final ProfessionalProfile p;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.text;
    final muted = t.bodyMedium!.copyWith(color: context.colors.muted);
    final place = [p.city, p.countryOfResidence].whereType<String>().join(', ');
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (OrbiMonogram.initialOf(p.name) != null &&
                  MediaQuery.textScalerOf(context).scale(16) <= 22)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s3),
                  child: OrbiMonogram(name: p.name, size: 48),
                ),
              Expanded(child: Text(p.name, style: t.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpace.s1),
          if (p.headline != null) Text(p.headline!, style: muted),
          if (place.isNotEmpty) Text(place, style: muted),
          if (p.contactEmail != null) Text(p.contactEmail!, style: muted),
          if (p.phone != null) Text(p.phone!, style: muted),
          if (p.workMode != null)
            Text(
              '${l.profileFieldWorkMode}: ${workModeLabel(l, p.workMode!)}',
              style: muted,
            ),
          if (p.summary != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(p.summary!, style: t.bodyMedium),
          ],
          if (p.skills.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s3),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s2,
              children: [for (final s in p.skills) OrbiStatusBadge(label: s)],
            ),
          ],
          const SizedBox(height: AppSpace.s3),
          OrbiSecondaryButton(
            label: l.profileEditAction,
            icon: Icons.edit_outlined,
            onPressed: () =>
                openProfileForm(context, ProfileFormPage(profile: p)),
          ),
        ],
      ),
    );
  }
}

String _period(BuildContext context, DateTime? start, DateTime? end, bool cur) {
  final l = AppLocalizations.of(context);
  final m = MaterialLocalizations.of(context);
  String f(DateTime d) => m.formatMonthYear(d);
  if (start == null && end == null) return '';
  final a = start == null ? '' : f(start);
  final b = end != null ? f(end) : (cur ? l.experiencePresent : '');
  return [a, b].where((e) => e.isNotEmpty).join(' – ');
}

Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required VoidCallback onConfirm,
}) async {
  final l = AppLocalizations.of(context);
  final ok = await showOrbiConfirm(
    context,
    title: title,
    message: l.commonDeleteConfirmBody,
    confirmLabel: l.commonDelete,
    cancelLabel: l.commonCancel,
    destructive: true,
  );
  if (ok) onConfirm();
}

class _ExperienceList extends StatelessWidget {
  const _ExperienceList(this.profile, this.items);
  final ProfessionalProfile profile;
  final List<Experience> items;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = context.text.bodySmall!.copyWith(color: context.colors.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrbiSectionHeader(title: l.experienceSection),
        const SizedBox(height: AppSpace.s2),
        if (items.isEmpty) Text(l.experienceEmpty, style: muted),
        for (final e in items)
          _Card(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: context.text.titleSmall),
                      Text(e.company, style: context.text.bodyMedium),
                      Text(
                        _period(context, e.startDate, e.endDate, e.isCurrent),
                        style: muted,
                      ),
                      if (e.description != null) ...[
                        const SizedBox(height: AppSpace.s1),
                        Text(e.description!, style: context.text.bodySmall),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.commonEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => openProfileForm(
                    context,
                    ExperienceFormPage(profileId: profile.id!, initial: e),
                  ),
                ),
                IconButton(
                  tooltip: l.commonDelete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(
                    context,
                    title: l.experienceDeleteTitle,
                    onConfirm: () =>
                        context.read<ProfileCubit>().removeExperience(e.id!),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpace.s2),
        OrbiSecondaryButton(
          label: l.experienceAdd,
          icon: Icons.add_rounded,
          onPressed: () => openProfileForm(
            context,
            ExperienceFormPage(profileId: profile.id!),
          ),
        ),
      ],
    );
  }
}

class _EducationList extends StatelessWidget {
  const _EducationList(this.profile, this.items);
  final ProfessionalProfile profile;
  final List<Education> items;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = context.text.bodySmall!.copyWith(color: context.colors.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrbiSectionHeader(title: l.educationSection),
        const SizedBox(height: AppSpace.s2),
        if (items.isEmpty) Text(l.educationEmpty, style: muted),
        for (final e in items)
          _Card(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.institution, style: context.text.titleSmall),
                      if ([e.degree, e.field].any((x) => x != null))
                        Text(
                          [e.degree, e.field].whereType<String>().join(' · '),
                          style: context.text.bodyMedium,
                        ),
                      Text(
                        _period(context, e.startDate, e.endDate, false),
                        style: muted,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.commonEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => openProfileForm(
                    context,
                    EducationFormPage(profileId: profile.id!, initial: e),
                  ),
                ),
                IconButton(
                  tooltip: l.commonDelete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(
                    context,
                    title: l.educationDeleteTitle,
                    onConfirm: () =>
                        context.read<ProfileCubit>().removeEducation(e.id!),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpace.s2),
        OrbiSecondaryButton(
          label: l.educationAdd,
          icon: Icons.add_rounded,
          onPressed: () => openProfileForm(
            context,
            EducationFormPage(profileId: profile.id!),
          ),
        ),
      ],
    );
  }
}
