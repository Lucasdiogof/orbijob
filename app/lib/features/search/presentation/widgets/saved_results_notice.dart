import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/orbi/orbi.dart';
import '../../../../l10n/app_localizations.dart';

/// Said above results that are the SAVED copy of a search, because the catalogue could not be reached (ORBI-001): when they were saved, that they may be
/// out of date, and a way to try again. Quiet on purpose (no error colours): the person still has everything they saw.
class SavedResultsNotice extends StatelessWidget {
  const SavedResultsNotice({
    super.key,
    required this.savedAt,
    required this.onRetry,
    this.compact = false,
  });

  final DateTime savedAt;
  final VoidCallback onRetry;

  /// Home sections: the line with the date only (the explanation sits once on Explore).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: OrbiCard(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 20,
              color: context.colors.muted,
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.offlineSavedBanner(savedAt.toLocal()),
                    style: context.text.bodyMedium,
                  ),
                  if (!compact) ...[
                    const SizedBox(height: AppSpace.s1),
                    Text(l.offlineMayBeOutdated, style: context.metadataStyle),
                  ],
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OrbiTextButton(
                      label: l.retry,
                      icon: Icons.refresh,
                      onPressed: onRetry,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
