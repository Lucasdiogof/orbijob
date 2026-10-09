import 'package:flutter/material.dart';

import '../../features/auth/presentation/auth_page.dart';
import '../../l10n/app_localizations.dart';
import '../data/data_failure.dart';
import '../design/design.dart';
import 'app_button.dart';
import 'skeleton.dart';
import 'state_view.dart';

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

/// Full-area state for a failed load: sign-in prompt, "not configured" notice or an error with retry. Each case
/// is distinct, so "no data", "offline" and "session ended" are never confused.
class DataFailureView extends StatelessWidget {
  const DataFailureView({super.key, required this.kind, this.onRetry});

  final DataFailureKind kind;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (needsSignIn(kind)) {
      return StateView(
        icon: Icons.lock_outline,
        title: l.dataSignInTitle,
        body: dataFailureText(l, kind),
        kind: StateKind.info,
        action: AppButton(
          label: l.accountSignIn,
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const AuthPage())),
        ),
      );
    }
    if (kind == DataFailureKind.notConfigured) {
      return StateView(
        icon: Icons.cloud_off_outlined,
        title: l.accountUnavailableTitle,
        body: dataFailureText(l, kind),
        kind: StateKind.info,
      );
    }
    return StateView(
      icon: Icons.error_outline,
      title: l.dataLoadErrorTitle,
      body: dataFailureText(l, kind),
      kind: StateKind.error,
      action: onRetry == null
          ? null
          : AppButton(label: l.retry, icon: Icons.refresh, onPressed: onRetry),
    );
  }
}

/// Neutral loading placeholder for lists.
class DataLoadingView extends StatelessWidget {
  const DataLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      label: l.commonLoading,
      liveRegion: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(height: 72),
            const SizedBox(height: AppSpace.s3),
          ],
        ],
      ),
    );
  }
}

/// Shows a failed action once as a snackbar.
void showDataFailure(BuildContext context, DataFailureKind kind) {
  final l = AppLocalizations.of(context);
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(dataFailureText(l, kind))));
}
