import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/orbi/orbi.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/professional_profile.dart';

/// What the profile still lacks, from real fields only (nothing is invented): returns the labels of the missing parts.
List<String> missingProfileParts(
  AppLocalizations l, {
  required ProfessionalProfile profile,
  required int experiences,
  required int education,
  required bool hasResume,
}) => [
  if (profile.headline == null) l.profileMissingHeadline,
  if (profile.countryOfResidence == null && profile.city == null)
    l.profileMissingLocation,
  if (profile.skills.isEmpty) l.profileMissingSkills,
  if (profile.summary == null) l.profileMissingSummary,
  if (experiences == 0) l.profileMissingExperience,
  if (education == 0) l.profileMissingEducation,
  if (!hasResume) l.profileMissingResume,
];

const profilePartsTotal = 7;

class ProfileCompletenessCard extends StatelessWidget {
  const ProfileCompletenessCard({super.key, required this.missing});
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final percent =
        (((profilePartsTotal - missing.length) / profilePartsTotal) * 100)
            .round();
    return OrbiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.profileCompletenessTitle(percent),
            style: context.text.titleSmall,
          ),
          const SizedBox(height: AppSpace.s2),
          Semantics(
            label: l.profileCompletenessTitle(percent),
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                backgroundColor: c.container,
                color: c.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          Text(
            missing.isEmpty
                ? l.profileCompletenessDone
                : l.profileCompletenessHint,
            style: context.text.bodySmall!.copyWith(color: c.muted),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s2),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s2,
              children: [for (final m in missing) OrbiStatusBadge(label: m)],
            ),
          ],
        ],
      ),
    );
  }
}
