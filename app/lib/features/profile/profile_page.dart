import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design.dart';
import '../../core/orbi/orbi.dart';
import '../../l10n/app_localizations.dart';
import '../auth/presentation/auth_cubit.dart';
import '../auth/presentation/auth_page.dart';
import '../hidden/presentation/hidden_jobs_page.dart';
import '../preferences/presentation/preferences_section.dart';
import '../privacy/presentation/your_data_section.dart';
import '../searches/presentation/saved_searches_page.dart';
import 'presentation/profile_cubit.dart';
import 'presentation/widgets/profile_completeness.dart';
import 'presentation/widgets/profile_sections.dart';
import 'presentation/widgets/resumes_section.dart';

/// Profile hub (reached from the header): the account at the top, then one row per area. Account, professional profile,
/// résumés, preferences, settings and privacy are separate screens, so nothing is a long scroll of unrelated forms.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _open(
    BuildContext context,
    String Function(AppLocalizations) title,
    Widget child,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _SubPage(title: title, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle), leading: const BackButton()),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: [
              const Reveal(child: _AccountCard()),
              const SizedBox(height: AppSpace.s5),
              _HubRow(
                icon: Icons.badge_outlined,
                title: l.profileSectionProfessional,
                index: 2,
                subtitle: l.profileHubProfessionalSub,
                onTap: () => _open(
                  context,
                  (x) => x.profileSectionProfessional,
                  const _Needs(
                    gate: OrbiGateKind.profile,
                    child: _ProfessionalView(),
                  ),
                ),
              ),
              _HubRow(
                icon: Icons.description_outlined,
                title: l.resumesSection,
                index: 3,
                subtitle: l.profileHubResumesSub,
                onTap: () => _open(
                  context,
                  (x) => x.resumesSection,
                  const _Needs(
                    gate: OrbiGateKind.resumes,
                    child: ResumesSection(),
                  ),
                ),
              ),
              _HubRow(
                icon: Icons.bookmarks_outlined,
                title: l.profileHubSavedSearches,
                index: 4,
                subtitle: l.profileHubSavedSearchesSub,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SavedSearchesPage(),
                  ),
                ),
              ),
              _HubRow(
                icon: Icons.visibility_off_outlined,
                title: l.hdTitle,
                index: 5,
                subtitle: l.hdProfileSub,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HiddenJobsPage(),
                  ),
                ),
              ),
              _HubRow(
                icon: Icons.tune_rounded,
                title: l.profileHubPreferences,
                index: 6,
                subtitle: l.profileHubPreferencesSub,
                onTap: () => _open(
                  context,
                  (x) => x.profileHubPreferences,
                  const _Needs(
                    gate: OrbiGateKind.savedSearches,
                    child: PreferencesSection(),
                  ),
                ),
              ),
              _HubRow(
                icon: Icons.settings_outlined,
                title: l.settingsTitle,
                index: 7,
                subtitle: l.profileHubSettingsSub,
                onTap: () => _open(
                  context,
                  (x) => x.settingsTitle,
                  const SettingsSection(),
                ),
              ),
              _HubRow(
                icon: Icons.shield_outlined,
                title: l.privacyTitle,
                index: 8,
                subtitle: l.profileHubPrivacySub,
                onTap: () =>
                    _open(context, (x) => x.privacyTitle, const _PrivacyView()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubRow extends StatefulWidget {
  const _HubRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.index = 1,
  });
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_HubRow> createState() => _HubRowState();
}

class _HubRowState extends State<_HubRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icon = widget.icon;
    final title = widget.title;
    final subtitle = widget.subtitle;
    return Reveal(
      index: widget.index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s3),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: OrbiCard(
            onTap: widget.onTap,
            child: Row(
              children: [
                // decorative tile: at very large text it yields its room to the words
                if (MediaQuery.textScalerOf(context).scale(16) <= 28)
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
                    child: Icon(icon, color: c.onPrimaryContainer),
                  ),
                if (MediaQuery.textScalerOf(context).scale(16) <= 28)
                  const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.text.bodySmall!.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
                AnimatedSlide(
                  offset: Offset(_hover && !reduceMotion(context) ? 0.2 : 0, 0),
                  duration: AppMotion.fast,
                  curve: AppMotion.curve,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _hover ? c.primary : c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A screen of the hub: back button, title and a centred column.
class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.child});
  final String Function(AppLocalizations) title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title(AppLocalizations.of(context))),
      leading: const BackButton(),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: child,
      ),
    ),
  );
}

/// Shows [child] only for a signed-in account; otherwise the gate that explains what the account gives.
class _Needs extends StatelessWidget {
  const _Needs({required this.gate, required this.child});
  final OrbiGateKind gate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = context.watch<AuthCubit>().state;
    if (!a.available) {
      return OrbiEmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.accountUnavailableTitle,
        body: l.accountUnavailableBody,
        kind: OrbiStateKind.info,
      );
    }
    if (!a.signedIn) return OrbiAuthGate(kind: gate);
    return child;
  }
}

class _ProfessionalView extends StatelessWidget {
  const _ProfessionalView();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = context.watch<ProfileCubit>().state;
    final p = s.profile;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        if (p != null) ...[
          ProfileCompletenessCard(
            missing: missingProfileParts(
              l,
              profile: p,
              experiences: s.experiences.length,
              education: s.education.length,
              hasResume: p.primaryResumeId != null,
            ),
          ),
          const SizedBox(height: AppSpace.s4),
        ],
        const ProfileSections(),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, s) {
        if (!s.available) {
          return OrbiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.accountUnavailableTitle, style: context.text.titleSmall),
                const SizedBox(height: AppSpace.s1),
                Text(
                  l.accountUnavailableBody,
                  style: context.text.bodyMedium!.copyWith(color: c.muted),
                ),
              ],
            ),
          );
        }
        final email = s.user?.email;
        return OrbiCard(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: c.primaryContainer,
                    foregroundColor: c.onPrimaryContainer,
                    child: s.signedIn && (email ?? '').isNotEmpty
                        ? Text(
                            email!.substring(0, 1).toUpperCase(),
                            style: context.text.titleMedium,
                          )
                        : const Icon(Icons.person_outline_rounded),
                  ),
                  const SizedBox(width: AppSpace.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.signedIn ? l.accountTitle : l.accountSignIn,
                          style: context.text.labelMedium!.copyWith(
                            color: c.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.signedIn
                              ? (email ?? l.accountSignedInNoEmail)
                              : l.accountSignedOutBody,
                          style: s.signedIn
                              ? context.text.titleSmall
                              : context.text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s4),
              if (s.signedIn)
                OrbiSecondaryButton(
                  label: l.accountSignOut,
                  icon: Icons.logout_rounded,
                  loading: s.busy,
                  onPressed: () => context.read<AuthCubit>().signOut(),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OrbiPrimaryButton(
                        label: l.accountSignIn,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AuthPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: OrbiSecondaryButton(
                        label: l.gateCreateAccount,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AuthPage(startAsSignUp: true),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PrivacyView extends StatelessWidget {
  const _PrivacyView();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    Widget group(String title, IconData icon, List<String> items) => OrbiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c.primary),
              const SizedBox(width: AppSpace.s2),
              Expanded(child: Text(title, style: context.text.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpace.s3),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: AppSpace.s2),
                    child: Icon(Icons.circle, size: 5, color: c.muted),
                  ),
                  Expanded(child: Text(i, style: context.text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        Text(
          l.privacyIntro,
          style: context.text.bodyMedium!.copyWith(color: c.muted),
        ),
        const SizedBox(height: AppSpace.s4),
        group(l.privacyKeepsTitle, Icons.lock_outline_rounded, [
          l.privacyKeeps1,
          l.privacyKeeps2,
          l.privacyKeeps3,
        ]),
        const SizedBox(height: AppSpace.s3),
        group(l.privacyNeverTitle, Icons.block_rounded, [
          l.privacyNever1,
          l.privacyNever2,
          l.privacyNever3,
        ]),
        const SizedBox(height: AppSpace.s5),
        const YourDataSection(),
      ],
    );
  }
}
