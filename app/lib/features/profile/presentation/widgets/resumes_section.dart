import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/data_failure.dart';
import '../../../../core/data/load_status.dart';
import '../../../../core/design/design.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/open_link.dart';
import '../../../../core/orbi/orbi.dart';
import '../../../../core/widgets/data_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/pdf_picker.dart';
import '../../domain/professional_profile.dart';
import '../../domain/resume_repository.dart';
import '../profile_cubit.dart';
import '../resume_import_page.dart';
import '../resumes_cubit.dart';

/// Résumés (private PDFs) of the profile. Appears only once a profile exists.
class ResumesSection extends StatelessWidget {
  const ResumesSection({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocSelector<ProfileCubit, ProfileState, ProfessionalProfile?>(
        selector: (s) => s.profile,
        builder: (context, p) {
          if (p?.id == null) {
            return OrbiEmptyState(
              icon: Icons.description_outlined,
              title: AppLocalizations.of(context).profileCreateTitle,
              body: AppLocalizations.of(context).profileCreateBody,
            );
          }
          return BlocProvider(
            key: ValueKey(p!.id),
            create: (_) => sl<ResumesCubit>(param1: p.id!)..load(),
            child: _ResumesView(profile: p),
          );
        },
      );
}

/// The file type is the same in every language.
const _fileKind = 'PDF';

enum _ResumeAction { open, suggest, makePrimary, replace, delete }

class _ResumesView extends StatelessWidget {
  const _ResumesView({required this.profile});
  final ProfessionalProfile profile;

  Future<PickedPdf?> _pick(BuildContext context) async {
    try {
      return await sl<PdfPicker>().pick();
    } on ResumeRejected catch (e) {
      if (context.mounted) showDataFailure(context, mapDataError(e));
    } catch (_) {
      if (context.mounted) showDataFailure(context, DataFailureKind.unknown);
    }
    return null;
  }

  Future<void> _upload(BuildContext context) async {
    final cubit = context.read<ResumesCubit>();
    final profiles = context.read<ProfileCubit>();
    final l = AppLocalizations.of(context);
    final picked = await _pick(context);
    if (picked == null) return;
    final firstOne = cubit.state.items.isEmpty;
    final ok = await cubit.upload(picked.bytes);
    if (!ok) return;
    // The first résumé becomes the main one on its own; the person can change it later.
    if (firstOne && profiles.state.profile!.primaryResumeId == null) {
      await profiles.saveProfile(
        profiles.state.profile!.copyWith(
          primaryResumeId: cubit.state.items.first.id,
        ),
      );
    }
    if (!context.mounted) return;
    showOrbiSnackBar(context, l.resumeUploaded, kind: OrbiSnackKind.success);
    // offer to read it (on the device) and suggest profile data; the user decides, and reviews everything
    final go = await showOrbiConfirm(
      context,
      title: l.resumeImportOfferTitle,
      message: l.resumeImportOfferBody,
      confirmLabel: l.resumeImportOfferYes,
      cancelLabel: l.resumeImportOfferNo,
    );
    if (go && context.mounted) await startResumeImport(context, picked.bytes);
  }

  Future<void> _suggest(BuildContext context, ResumeFile f) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<ResumesCubit>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final bytes = await cubit.fetchBytes(f);
    if (bytes == null) {
      showOrbiSnackBarOn(messenger, l.resumeImportDownloadFailed);
      return;
    }
    if (context.mounted) await startResumeImport(context, bytes);
  }

  Future<void> _replace(BuildContext context, ResumeFile old) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<ResumesCubit>();
    final profiles = context.read<ProfileCubit>();
    final go = await showOrbiConfirm(
      context,
      title: l.resumeReplaceTitle,
      message: l.resumeReplaceBody,
      confirmLabel: l.resumeChooseFile,
      cancelLabel: l.commonCancel,
    );
    if (!go || !context.mounted) return;
    final picked = await _pick(context);
    if (picked == null) return;
    // Upload first; the old file is only removed once the new one is safely stored.
    final wasPrimary = profiles.state.profile!.primaryResumeId == old.id;
    if (cubit.state.items.length >= ResumeRepository.maxFiles) {
      await cubit.delete(old);
    }
    final ok = await cubit.upload(picked.bytes);
    if (!ok) return;
    final fresh = cubit.state.items.first;
    if (cubit.state.items.any((f) => f.id == old.id)) await cubit.delete(old);
    if (wasPrimary) {
      await profiles.saveProfile(
        profiles.state.profile!.copyWith(primaryResumeId: fresh.id),
      );
    }
    if (context.mounted) {
      showOrbiSnackBar(context, l.resumeReplaced, kind: OrbiSnackKind.success);
    }
  }

  Future<void> _delete(BuildContext context, ResumeFile f) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<ResumesCubit>();
    final profiles = context.read<ProfileCubit>();
    final ok = await showOrbiConfirm(
      context,
      title: l.resumeDeleteTitle,
      message: l.resumeDeleteBody,
      confirmLabel: l.commonDelete,
      cancelLabel: l.commonCancel,
      destructive: true,
    );
    if (!ok) return;
    await cubit.delete(f);
    if (profiles.state.profile!.primaryResumeId == f.id) {
      await profiles.saveProfile(
        profiles.state.profile!.copyWith(clearPrimaryResume: true),
      );
    }
  }

  Future<void> _makePrimary(BuildContext context, ResumeFile f) async {
    final l = AppLocalizations.of(context);
    final profiles = context.read<ProfileCubit>();
    final ok = await profiles.saveProfile(
      profiles.state.profile!.copyWith(primaryResumeId: f.id),
    );
    if (ok && context.mounted) {
      showOrbiSnackBar(
        context,
        l.resumePrimarySet,
        kind: OrbiSnackKind.success,
      );
    }
  }

  Future<void> _open(BuildContext context, ResumeFile f) async {
    final url = await context.read<ResumesCubit>().openLink(f);
    if (url != null) await openExternalLink(url);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final fmt = MaterialLocalizations.of(context);
    // The main résumé follows the profile (it may change while this view is open).
    final primaryId = context.select<ProfileCubit, String?>(
      (p) => p.state.profile?.primaryResumeId,
    );
    return BlocConsumer<ResumesCubit, ResumesState>(
      listenWhen: (a, b) => a.actionTick != b.actionTick,
      listener: (context, s) {
        if (s.actionFailure != null) showDataFailure(context, s.actionFailure!);
      },
      builder: (context, s) {
        if (s.status == LoadStatus.loading) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.s4),
            child: OrbiSkeletonList(count: 2),
          );
        }
        if (s.status == LoadStatus.failure) {
          return DataFailureView(
            kind: s.failure!,
            onRetry: () => context.read<ResumesCubit>().load(),
          );
        }
        final ordered = [
          ...s.items.where((f) => f.id == primaryId),
          ...s.items.where((f) => f.id != primaryId),
        ];
        return ListView(
          padding: const EdgeInsets.all(AppSpace.s4),
          children: [
            Text(
              l.resumesBody,
              style: context.text.bodyMedium!.copyWith(color: c.muted),
            ),
            const SizedBox(height: AppSpace.s4),
            if (s.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                child: Column(
                  children: [
                    const OrbiArt(icon: Icons.description_outlined, size: 96),
                    const SizedBox(height: AppSpace.s4),
                    Reveal(
                      index: 1,
                      child: Text(
                        l.resumesEmpty,
                        style: context.text.bodyMedium!.copyWith(
                          color: c.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            for (final (i, f) in ordered.indexed) ...[
              Reveal(
                index: i,
                child: OrbiCard(
                  selected: f.id == primaryId,
                  onTap: s.busyId == null ? () => _open(context, f) : null,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              c.primaryContainer,
                              Color.lerp(c.primaryContainer, c.primary, 0.18)!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf_outlined,
                          color: c.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.resumeItem(fmt.formatMediumDate(f.createdAt)),
                              style: context.text.titleSmall,
                            ),
                            const SizedBox(height: AppSpace.s1),
                            Text(_fileKind, style: context.metadataStyle),
                          ],
                        ),
                      ),
                      if (f.id == primaryId) ...[
                        OrbiStatusBadge(
                          label: l.resumePrimary,
                          kind: OrbiBadgeKind.info,
                          icon: Icons.star_rounded,
                        ),
                        const SizedBox(width: AppSpace.s1),
                      ],
                      if (s.busyId == f.id)
                        const Padding(
                          padding: EdgeInsets.all(AppSpace.s2),
                          child: OrbiLoadingIndicator(size: 22),
                        )
                      else
                        PopupMenuButton<_ResumeAction>(
                          tooltip: l.resumeMoreActions,
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (a) => switch (a) {
                            _ResumeAction.open => _open(context, f),
                            _ResumeAction.suggest => _suggest(context, f),
                            _ResumeAction.makePrimary => _makePrimary(
                              context,
                              f,
                            ),
                            _ResumeAction.replace => _replace(context, f),
                            _ResumeAction.delete => _delete(context, f),
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: _ResumeAction.open,
                              child: Text(l.resumeOpen),
                            ),
                            PopupMenuItem(
                              value: _ResumeAction.suggest,
                              child: Text(l.resumeSuggestAction),
                            ),
                            if (f.id != primaryId)
                              PopupMenuItem(
                                value: _ResumeAction.makePrimary,
                                child: Text(l.resumeSetPrimary),
                              ),
                            PopupMenuItem(
                              value: _ResumeAction.replace,
                              child: Text(l.resumeReplace),
                            ),
                            PopupMenuItem(
                              value: _ResumeAction.delete,
                              child: Text(l.commonDelete),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
            ],
            const SizedBox(height: AppSpace.s2),
            OrbiPrimaryButton(
              label: s.uploading ? l.resumesUploading : l.resumesUpload,
              icon: Icons.upload_file_outlined,
              loading: s.uploading,
              expand: true,
              onPressed: s.uploading ? null : () => _upload(context),
            ),
          ],
        );
      },
    );
  }
}
