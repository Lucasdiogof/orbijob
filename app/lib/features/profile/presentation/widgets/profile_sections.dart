import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/load_status.dart';
import '../../../../core/design/design.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/data_state_view.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/professional_profile.dart';
import '../profile_cubit.dart';
import 'profile_forms.dart';

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(padding: const EdgeInsets.all(AppSpace.s4), child: child),
    );
  }
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
          body = const Column(
            children: [
              SkeletonBox(height: 72),
              SizedBox(height: AppSpace.s3),
              SkeletonBox(height: 72),
            ],
          );
        } else if (s.status == LoadStatus.failure) {
          body = SizedBox(
            height: 280,
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
                AppButton(
                  label: l.profileCreateAction,
                  onPressed: () =>
                      openProfileForm(context, const ProfileFormPage()),
                ),
              ],
            ),
          );
        } else {
          final p = s.profile!;
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileCard(p),
              const SizedBox(height: AppSpace.s6),
              _ExperienceList(p, s.experiences),
              const SizedBox(height: AppSpace.s6),
              _EducationList(p, s.education),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l.profileSectionProfessional),
            const SizedBox(height: AppSpace.s3),
            body,
          ],
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
          Text(p.name, style: t.titleMedium),
          if (p.headline != null) Text(p.headline!, style: muted),
          if (place.isNotEmpty) Text(place, style: muted),
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
              children: [for (final s in p.skills) Chip(label: Text(s))],
            ),
          ],
          const SizedBox(height: AppSpace.s3),
          AppButton(
            label: l.profileEditAction,
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.secondary,
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
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(l.commonDeleteConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.commonDelete),
        ),
      ],
    ),
  );
  if (ok == true) onConfirm();
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
        Text(l.experienceSection, style: context.text.titleSmall),
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
        AppButton(
          label: l.experienceAdd,
          icon: Icons.add,
          variant: AppButtonVariant.secondary,
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
        Text(l.educationSection, style: context.text.titleSmall),
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
        AppButton(
          label: l.educationAdd,
          icon: Icons.add,
          variant: AppButtonVariant.secondary,
          onPressed: () => openProfileForm(
            context,
            EducationFormPage(profileId: profile.id!),
          ),
        ),
      ],
    );
  }
}
