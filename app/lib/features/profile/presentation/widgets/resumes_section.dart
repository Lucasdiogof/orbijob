import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/load_status.dart';
import '../../../../core/design/design.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/open_link.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/data_state_view.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/pdf_picker.dart';
import '../../domain/professional_profile.dart';
import '../../domain/resume_repository.dart';
import '../profile_cubit.dart';
import '../resumes_cubit.dart';
import '../../../../core/data/data_failure.dart';

/// Résumés (private PDFs) of the profile. Appears only once a profile exists.
class ResumesSection extends StatelessWidget {
  const ResumesSection({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocSelector<ProfileCubit, ProfileState, ProfessionalProfile?>(
        selector: (s) => s.profile,
        builder: (context, p) {
          if (p?.id == null) return const SizedBox.shrink();
          return BlocProvider(
            key: ValueKey(p!.id),
            create: (_) => sl<ResumesCubit>(param1: p.id!)..load(),
            child: const _ResumesView(),
          );
        },
      );
}

class _ResumesView extends StatelessWidget {
  const _ResumesView();

  Future<void> _upload(BuildContext context) async {
    final cubit = context.read<ResumesCubit>();
    final l = AppLocalizations.of(context);
    PickedPdf? picked;
    try {
      picked = await sl<PdfPicker>().pick();
    } on ResumeRejected catch (e) {
      if (context.mounted) {
        showDataFailure(context, mapDataError(e));
      }
      return;
    } catch (_) {
      if (context.mounted) showDataFailure(context, DataFailureKind.unknown);
      return;
    }
    if (picked == null) return;
    final ok = await cubit.upload(picked.bytes);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.resumeUploaded)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = context.text.bodySmall!.copyWith(color: context.colors.muted);
    final fmt = MaterialLocalizations.of(context);
    return BlocConsumer<ResumesCubit, ResumesState>(
      listenWhen: (a, b) => a.actionTick != b.actionTick,
      listener: (context, s) {
        if (s.actionFailure != null) showDataFailure(context, s.actionFailure!);
      },
      builder: (context, s) {
        Widget body;
        if (s.status == LoadStatus.loading) {
          body = const LinearProgressIndicator();
        } else if (s.status == LoadStatus.failure) {
          body = SizedBox(
            height: 240,
            child: DataFailureView(
              kind: s.failure!,
              onRetry: () => context.read<ResumesCubit>().load(),
            ),
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.resumesBody, style: muted),
              const SizedBox(height: AppSpace.s2),
              if (s.items.isEmpty) Text(l.resumesEmpty, style: muted),
              for (final f in s.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(l.resumeItem(fmt.formatMediumDate(f.createdAt))),
                  trailing: s.busyId == f.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l.resumeOpen,
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () async {
                                final url = await context
                                    .read<ResumesCubit>()
                                    .openLink(f);
                                if (url != null) await openExternalLink(url);
                              },
                            ),
                            IconButton(
                              tooltip: l.commonDelete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirm(context, f),
                            ),
                          ],
                        ),
                ),
              const SizedBox(height: AppSpace.s2),
              AppButton(
                label: s.uploading ? l.resumesUploading : l.resumesUpload,
                icon: Icons.upload_file_outlined,
                variant: AppButtonVariant.secondary,
                loading: s.uploading,
                onPressed: s.uploading ? null : () => _upload(context),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l.resumesSection),
            const SizedBox(height: AppSpace.s3),
            body,
          ],
        );
      },
    );
  }

  Future<void> _confirm(BuildContext context, ResumeFile f) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<ResumesCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.resumeDeleteTitle),
        content: Text(l.resumeDeleteBody),
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
    if (ok == true) await cubit.delete(f);
  }
}
