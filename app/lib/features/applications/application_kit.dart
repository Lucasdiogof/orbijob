import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design.dart';
import '../../core/di/injector.dart';
import '../../core/open_link.dart';
import '../../core/orbi/orbi.dart';
import '../../l10n/app_localizations.dart';
import '../auth/presentation/auth_cubit.dart';
import '../auth/presentation/auth_page.dart';
import '../profile/domain/professional_profile.dart';
import '../profile/domain/resume_repository.dart';
import '../profile/presentation/profile_cubit.dart';
import '../search/data/job_snapshot.dart' show manualSource;
import '../search/domain/entities/job_posting.dart';
import 'applications_cubit.dart';
import 'domain/application_record.dart';

/// One piece of profile data the person may want to paste into an external application form.
class KitField {
  const KitField(this.label, this.value, {this.multiline = false});
  final String label;
  final String value;
  final bool multiline;
}

/// The data of a profile as copyable fields. Only what exists is listed; nothing is made up and nothing is rewritten.
List<KitField> kitFields(
  AppLocalizations l,
  ProfessionalProfile p, {
  List<Experience> experiences = const [],
  List<Education> education = const [],
  MaterialLocalizations? dates,
}) {
  String period(DateTime? a, DateTime? b, bool current) {
    if (dates == null || (a == null && b == null)) return '';
    final from = a == null ? '' : dates.formatMonthYear(a);
    final to = current
        ? l.resumeImportPresent
        : (b == null ? '' : dates.formatMonthYear(b));
    return ' (${l.resumeImportDates(from, to)})';
  }

  final place = [p.city, p.countryOfResidence].whereType<String>().join(', ');
  final latestJob = experiences.isEmpty ? null : experiences.first;
  final latestEdu = education.isEmpty ? null : education.first;
  return [
    KitField(l.profileFieldName, p.name),
    if (p.headline != null) KitField(l.profileFieldHeadline, p.headline!),
    if (p.contactEmail != null) KitField(l.profileFieldEmail, p.contactEmail!),
    if (p.phone != null) KitField(l.profileFieldPhone, p.phone!),
    if (place.isNotEmpty) KitField(l.kitLocation, place),
    if (p.links.isNotEmpty)
      KitField(l.kitLinks, p.links.join('\n'), multiline: true),
    if (p.summary != null)
      KitField(l.profileFieldSummary, p.summary!, multiline: true),
    if (p.skills.isNotEmpty)
      KitField(l.profileFieldSkills, p.skills.join(', ')),
    if (latestJob != null)
      KitField(
        l.kitLastJob,
        '${latestJob.title} — ${latestJob.company}${period(latestJob.startDate, latestJob.endDate, latestJob.isCurrent)}',
      ),
    if (latestEdu != null)
      KitField(
        l.kitLastEducation,
        [
          [latestEdu.degree, latestEdu.field].whereType<String>().join(' · '),
          latestEdu.institution,
        ].where((e) => e.isNotEmpty).join(' — '),
      ),
  ];
}

/// The "application kit" of a job: the honest alternative to auto-filling other sites' forms. It lets the person copy their
/// own profile data piece by piece (or all at once), open their main résumé to download it, open the original listing, and
/// record the application afterwards. Nothing is sent anywhere and no third-party page is touched.
Future<void> showApplicationKit(BuildContext context, JobPosting job) =>
    showOrbiSheet<void>(context, builder: (_) => _KitSheet(job: job));

class _KitSheet extends StatelessWidget {
  const _KitSheet({required this.job});
  final JobPosting job;

  Future<void> _copy(BuildContext context, String field, String value) async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      showOrbiSnackBar(
        context,
        l.kitCopied(field),
        kind: OrbiSnackKind.success,
      );
    }
  }

  Future<void> _openMainResume(
    BuildContext context,
    ProfessionalProfile p,
  ) async {
    final id = p.primaryResumeId;
    if (id == null || p.id == null) return;
    final repo = sl<ResumeRepository>();
    try {
      final files = await repo.list(p.id!);
      final file = files.where((f) => f.id == id).firstOrNull;
      if (file == null) return;
      final url = await repo.signedUrl(file);
      await openExternalLink(url);
    } catch (_) {
      if (context.mounted) {
        showOrbiSnackBar(
          context,
          AppLocalizations.of(context).applicationLinkCannotOpen,
          kind: OrbiSnackKind.error,
        );
      }
    }
  }

  Future<void> _track(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<ApplicationsCubit>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await showOrbiConfirm(
      context,
      title: l.kitTrackConfirmTitle,
      message: l.kitTrackConfirmBody,
      confirmLabel: l.kitTrack,
    );
    if (!ok) return;
    final created = await cubit.create(
      company: job.company.isEmpty ? job.title : job.company,
      title: job.title,
      link: hasListing ? job.originalUrl : null,
      channel: job.sourceName,
      stage: ApplicationStage.applied,
      appliedAt: DateTime.now(),
    );
    if (created) {
      nav.pop();
      showSavedFeedback(messenger, l.kitTracked);
    }
  }

  bool get hasListing =>
      job.source != manualSource && job.originalUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final auth = context.watch<AuthCubit>().state;
    final ps = context.watch<ProfileCubit>().state;
    final p = ps.profile;
    final fields = p == null
        ? const <KitField>[]
        : kitFields(
            l,
            p,
            experiences: ps.experiences,
            education: ps.education,
            dates: MaterialLocalizations.of(context),
          );
    return OrbiSheetScaffold(
      title: l.kitTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.kitIntro,
            style: context.text.bodyMedium!.copyWith(color: c.muted),
          ),
          const SizedBox(height: AppSpace.s4),
          if (!auth.signedIn) ...[
            OrbiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.kitSignIn, style: context.text.bodyMedium),
                  const SizedBox(height: AppSpace.s3),
                  OrbiSecondaryButton(
                    label: l.accountSignIn,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AuthPage()),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (fields.isEmpty) ...[
            OrbiCard(child: Text(l.kitEmpty, style: context.text.bodyMedium)),
          ] else ...[
            for (final f in fields) ...[
              OrbiCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s4,
                  AppSpace.s3,
                  AppSpace.s2,
                  AppSpace.s3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.label, style: context.metadataStyle),
                          const SizedBox(height: 2),
                          Text(
                            f.value,
                            style: context.text.bodyMedium,
                            maxLines: f.multiline ? 4 : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l.kitCopy(f.label),
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () => _copy(context, f.label, f.value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s2),
            ],
            const SizedBox(height: AppSpace.s2),
            OrbiSecondaryButton(
              label: l.kitCopyAll,
              icon: Icons.copy_all_rounded,
              onPressed: () => _copy(
                context,
                l.kitAllCopied,
                [for (final f in fields) '${f.label}: ${f.value}'].join('\n'),
              ),
            ),
            if (p!.primaryResumeId != null) ...[
              const SizedBox(height: AppSpace.s2),
              OrbiSecondaryButton(
                label: l.kitMainResume,
                icon: Icons.description_outlined,
                onPressed: () => _openMainResume(context, p),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s1),
                child: Text(l.kitMainResumeHint, style: context.metadataStyle),
              ),
            ],
          ],
        ],
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasListing)
            OrbiPrimaryButton(
              label: l.openOriginalListing,
              icon: Icons.open_in_new_rounded,
              expand: true,
              onPressed: () async {
                final ok = await openExternalLink(job.originalUrl);
                if (!ok && context.mounted) {
                  showOrbiSnackBar(
                    context,
                    l.applicationLinkCannotOpen,
                    kind: OrbiSnackKind.error,
                  );
                }
              },
            )
          else
            Text(
              l.kitNoListing,
              style: context.metadataStyle,
              textAlign: TextAlign.center,
            ),
          if (auth.signedIn) ...[
            const SizedBox(height: AppSpace.s2),
            OrbiTextButton(label: l.kitTrack, onPressed: () => _track(context)),
          ],
        ],
      ),
    );
  }
}
