import 'package:flutter/material.dart';

import '../../features/auth/presentation/auth_page.dart';
import '../../l10n/app_localizations.dart';
import '../design/design.dart';
import 'orbi_art.dart';
import 'orbi_buttons.dart';

/// What the person was trying to do when the account was needed: each gets its own promise, never a generic padlock.
enum OrbiGateKind { favorites, applications, resumes, profile, savedSearches }

/// Contextual state for a feature that needs an account: the benefit in one line, three concrete reasons, then
/// "Sign in" and "Create account" and, when there is somewhere to go, a way to keep exploring without one.
class OrbiAuthGate extends StatelessWidget {
  const OrbiAuthGate({super.key, required this.kind, this.onContinue});

  final OrbiGateKind kind;

  /// "Keep exploring": shown when set (a tab of the shell sends the person back to Explore).
  final VoidCallback? onContinue;

  (IconData, String, String, List<String>) _copy(AppLocalizations l) =>
      switch (kind) {
        OrbiGateKind.favorites => (
          Icons.bookmark_border_rounded,
          l.gateFavoritesTitle,
          l.gateFavoritesBody,
          [l.gateFavorites1, l.gateFavorites2, l.gateFavorites3],
        ),
        OrbiGateKind.applications => (
          Icons.assignment_turned_in_outlined,
          l.gateApplicationsTitle,
          l.gateApplicationsBody,
          [l.gateApplications1, l.gateApplications2, l.gateApplications3],
        ),
        OrbiGateKind.resumes => (
          Icons.description_outlined,
          l.gateResumesTitle,
          l.gateResumesBody,
          [l.gateResumes1, l.gateResumes2, l.gateResumes3],
        ),
        OrbiGateKind.profile => (
          Icons.badge_outlined,
          l.gateProfileTitle,
          l.gateProfileBody,
          [l.gateProfile1, l.gateProfile2, l.gateProfile3],
        ),
        OrbiGateKind.savedSearches => (
          Icons.notifications_none_rounded,
          l.gateSavedSearchesTitle,
          l.gateSavedSearchesBody,
          [l.gateSavedSearches1, l.gateSavedSearches2, l.gateSavedSearches3],
        ),
      };

  void _open(BuildContext context, {required bool signUp}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AuthPage(startAsSignUp: signUp),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final (icon, title, body, benefits) = _copy(l);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: box.hasBoundedHeight ? box.maxHeight : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s6),
                child: Semantics(
                  container: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OrbiArt(icon: icon),
                      const SizedBox(height: AppSpace.s5),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: context.text.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        body,
                        style: context.text.bodyMedium!.copyWith(
                          color: c.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpace.s5),
                      for (final b in benefits)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: c.success,
                                ),
                              ),
                              const SizedBox(width: AppSpace.s3),
                              Expanded(
                                child: Text(b, style: context.text.bodyMedium),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpace.s5),
                      OrbiPrimaryButton(
                        label: l.gateCreateAccount,
                        expand: true,
                        onPressed: () => _open(context, signUp: true),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      OrbiSecondaryButton(
                        label: l.accountSignIn,
                        expand: true,
                        onPressed: () => _open(context, signUp: false),
                      ),
                      if (onContinue != null) ...[
                        const SizedBox(height: AppSpace.s1),
                        OrbiTextButton(
                          label: l.gateKeepExploring,
                          icon: Icons.explore_outlined,
                          expand: true,
                          onPressed: onContinue,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
