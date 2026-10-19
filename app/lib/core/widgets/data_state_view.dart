import 'package:flutter/material.dart';

import '../../features/auth/presentation/auth_page.dart';
import '../../l10n/app_localizations.dart';
import '../data/data_failure.dart';
import '../design/design.dart';
import '../orbi/orbi.dart';

/// Localised message for a failure kind (never the raw server text).
String dataFailureText(AppLocalizations l, DataFailureKind k) => switch (k) {
  DataFailureKind.notConfigured => l.dataFailureNotConfigured,
  DataFailureKind.signedOut => l.dataFailureSignedOut,
  DataFailureKind.sessionExpired => l.dataFailureSessionExpired,
  DataFailureKind.network => l.dataFailureNetwork,
  DataFailureKind.denied => l.dataFailureDenied,
  DataFailureKind.quotaExceeded => l.dataFailureQuota,
  DataFailureKind.duplicate => l.dataFailureDuplicate,
  DataFailureKind.invalidInput => l.dataFailureInvalid,
  DataFailureKind.tooLarge => l.dataFailureTooLarge,
  DataFailureKind.notPdf => l.dataFailureNotPdf,
  DataFailureKind.emptyFile => l.dataFailureEmptyFile,
  DataFailureKind.notFound => l.dataFailureNotFound,
  DataFailureKind.unavailable => l.dataFailureUnavailable,
  DataFailureKind.unknown => l.dataFailureUnknown,
};

/// Full-area state for a failed load: contextual sign-in gate, "not configured" notice or an error with retry. Each case
/// is distinct, so "no data", "offline" and "session ended" are never confused.
class DataFailureView extends StatelessWidget {
  const DataFailureView({
    super.key,
    required this.kind,
    this.onRetry,
    this.gate,
    this.onContinue,
  });

  final DataFailureKind kind;
  final VoidCallback? onRetry;

  /// When the failure is "sign in", which feature asked for the account (drives the gate copy).
  final OrbiGateKind? gate;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (needsSignIn(kind)) {
      if (gate != null) {
        return OrbiAuthGate(kind: gate!, onContinue: onContinue);
      }
      return OrbiEmptyState(
        icon: Icons.lock_outline_rounded,
        title: l.dataSignInTitle,
        body: dataFailureText(l, kind),
        kind: OrbiStateKind.info,
        action: OrbiPrimaryButton(
          label: l.accountSignIn,
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const AuthPage())),
        ),
      );
    }
    if (kind == DataFailureKind.notConfigured) {
      return OrbiEmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.accountUnavailableTitle,
        body: dataFailureText(l, kind),
        kind: OrbiStateKind.info,
      );
    }
    return OrbiEmptyState(
      icon: Icons.error_outline_rounded,
      title: l.dataLoadErrorTitle,
      body: dataFailureText(l, kind),
      kind: OrbiStateKind.error,
      action: onRetry == null
          ? null
          : OrbiPrimaryButton(
              label: l.retry,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
    );
  }
}

/// Loading placeholder for lists: job-card skeletons.
class DataLoadingView extends StatelessWidget {
  const DataLoadingView({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).commonLoading,
    liveRegion: true,
    child: const Padding(
      padding: EdgeInsets.all(AppSpace.s4),
      child: OrbiSkeletonList(count: 3),
    ),
  );
}

/// Shows a failed action once as a snackbar.
void showDataFailure(BuildContext context, DataFailureKind kind) {
  final l = AppLocalizations.of(context);
  showOrbiSnackBar(
    context,
    dataFailureText(l, kind),
    kind: OrbiSnackKind.error,
  );
}
