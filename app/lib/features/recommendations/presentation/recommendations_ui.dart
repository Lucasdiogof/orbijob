import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../translation/translation_widgets.dart';
import '../../../core/design/design.dart';
import '../../../core/orbi/orbi.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../favorites/favorites_cubit.dart';
import '../../hidden/presentation/hidden_jobs_cubit.dart';
import '../../jobs/job_actions_menu.dart';
import '../../preferences/presentation/preferences_cubit.dart';
import '../../profile/profile_page.dart';
import '../../profile/presentation/profile_cubit.dart';
import '../../search/domain/entities/job_posting.dart';
import '../../search/presentation/pages/job_detail_page.dart';
import '../../searches/presentation/search_labels.dart';
import '../domain/recommendation.dart';
import '../domain/recommender.dart';
import 'recommendation_text.dart';
import 'recommendations_cubit.dart';

/// Feeds the recommendations: whenever the profile, the experience or the countries of interest are (re)loaded or changed, asks the cubit to
/// recompute. Sits inside the account scope, so a different account never inherits another's list.
class RecommendationsFeeder extends StatefulWidget {
  const RecommendationsFeeder({super.key, required this.child});
  final Widget child;

  @override
  State<RecommendationsFeeder> createState() => _RecommendationsFeederState();
}

class _RecommendationsFeederState extends State<RecommendationsFeeder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _feed(context);
    });
  }

  void _feed(BuildContext context) {
    final profile = context.read<ProfileCubit>().state;
    final prefs = context.read<PreferencesCubit>().state;
    final signedIn = context.read<AuthCubit>().state.signedIn;
    final cubit = context.read<RecommendationsCubit>();
    if (!signedIn) {
      cubit.refresh(null);
      return;
    }
    cubit.refresh(
      RecommendationProfile.from(
        profile.profile,
        profile.experiences,
        prefs.prefs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<ProfileCubit, ProfileState>(
        listenWhen: (a, b) =>
            a.profile != b.profile || a.experiences != b.experiences,
        listener: (context, _) => _feed(context),
      ),
      BlocListener<PreferencesCubit, PreferencesState>(
        listenWhen: (a, b) =>
            a.prefs.countriesOfInterest != b.prefs.countriesOfInterest,
        listener: (context, _) => _feed(context),
      ),
      BlocListener<AuthCubit, AuthState>(
        listenWhen: (a, b) => a.signedIn != b.signedIn,
        listener: (context, _) => _feed(context),
      ),
    ],
    child: widget.child,
  );
}

/// "Why this job?" — the reasons, the things to check, and what is NOT checked.
Future<void> showWhySheet(BuildContext context, Recommendation r) {
  final l = AppLocalizations.of(context);
  final lang = langOf(context);
  return showOrbiSheet<void>(
    context,
    builder: (ctx) => OrbiSheetScaffold(
      title: l.rcWhyTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedTitle(
            job: r.job,
            builder: (c, title, translated) =>
                Text(title, style: ctx.text.titleMedium),
          ),
          if (r.job.company.isNotEmpty)
            Text(r.job.company, style: ctx.text.bodyMedium),
          const SizedBox(height: AppSpace.s2),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s1,
            children: [
              OrbiStatusBadge(
                label: fitLabel(r.fit, l),
                kind: switch (r.fit) {
                  Fit.strong => OrbiBadgeKind.success,
                  Fit.good => OrbiBadgeKind.info,
                  Fit.possible => OrbiBadgeKind.neutral,
                },
              ),
              OrbiStatusBadge(label: l.rcScore(r.score)),
              OrbiStatusBadge(label: l.rcSignals(r.signals)),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          if (r.reasons.isNotEmpty) ...[
            OrbiFieldLabel(l.rcMatches),
            for (final x in r.reasons)
              _Line(
                icon: Icons.check_circle_outline_rounded,
                text: reasonText(x, l, lang),
              ),
          ],
          if (r.caveats.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s3),
            OrbiFieldLabel(l.rcCheck),
            for (final c in r.caveats)
              _Line(
                icon: Icons.info_outline_rounded,
                text: caveatText(c, l, lang),
              ),
          ],
          const SizedBox(height: AppSpace.s4),
          Text(l.rcDisclaimer, style: ctx.metadataStyle),
        ],
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: context.colors.muted),
        ),
        const SizedBox(width: AppSpace.s2),
        Expanded(child: Text(text, style: context.text.bodyMedium)),
      ],
    ),
  );
}

/// One recommended job: the card, then the fit label and the two strongest reasons in words, and the way to the full explanation.
class RecommendedJobTile extends StatelessWidget {
  const RecommendedJobTile({super.key, required this.rec, this.compact = true});
  final Recommendation rec;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = langOf(context);
    final job = rec.job;
    final scored = ScoredJob(job);
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, favs) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrbiJobCard(
            scored: scored,
            compact: compact,
            menu: JobActionsMenu(job: job),
            isFavorite: favs.items.containsKey(FavoritesCubit.keyOf(job)),
            onFavoriteChanged: (_) =>
                context.read<FavoritesCubit>().toggle(scored),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => JobDetailPage(scored: scored),
              ),
            ),
          ),
          Padding(
            // aligned with the text inside the card, close to it: the explanation belongs to THIS job
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s2,
              AppSpace.s4,
              AppSpace.s2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OrbiStatusBadge(
                      label: fitLabel(rec.fit, l),
                      kind: switch (rec.fit) {
                        Fit.strong => OrbiBadgeKind.success,
                        Fit.good => OrbiBadgeKind.info,
                        Fit.possible => OrbiBadgeKind.neutral,
                      },
                    ),
                    for (final r in rec.reasons.take(2))
                      Text(
                        reasonText(r, l, lang),
                        style: context.metadataStyle,
                      ),
                  ],
                ),
                _WhyLink(onTap: () => showWhySheet(context, rec)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Why this job?" as a compact link under the explanation (a full 48 px button left a wide gap): the tap area still reaches 44 px.
class _WhyLink extends StatelessWidget {
  const _WhyLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 18,
                  color: context.colors.primary,
                ),
                const SizedBox(width: AppSpace.s1),
                Flexible(
                  child: Text(
                    l.rcWhy,
                    style: context.text.labelLarge?.copyWith(
                      color: context.colors.primary,
                    ),
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

/// A short card for Home: icon, one line of text and an optional action. Home is a dashboard; a full-height empty state would push everything else away.
class _CompactNote extends StatelessWidget {
  const _CompactNote({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => OrbiCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.colors.primary),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, style: context.metadataStyle),
                ],
              ),
            ),
          ],
        ),
        if (action != null) ...[const SizedBox(height: AppSpace.s2), action!],
      ],
    ),
  );
}

/// What the recommendations area says when there is nothing to list (profile missing, nothing matches, signed out...). [compact] is the Home
/// version (a card); the full page uses the standard empty state.
Widget? recommendationsMessage(
  BuildContext context,
  RecommendationsState s, {
  bool compact = false,
}) {
  final l = AppLocalizations.of(context);
  final signedIn = context.read<AuthCubit>().state.signedIn;
  Widget make(
    IconData icon,
    String title,
    String body, {
    Widget? action,
    bool error = false,
  }) => compact
      ? _CompactNote(icon: icon, title: title, body: body, action: action)
      : OrbiEmptyState(
          icon: icon,
          title: title,
          body: body,
          kind: error ? OrbiStateKind.error : OrbiStateKind.info,
          action: action,
        );
  switch (s.status) {
    case RecStatus.needsProfile:
      void open() => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ProfilePage()));
      return make(
        Icons.badge_outlined,
        l.rcNeedProfileTitle,
        signedIn ? l.rcNeedProfileBody : l.rcSignInBody,
        action: compact
            ? OrbiTextButton(label: l.rcNeedProfileAction, onPressed: open)
            : OrbiPrimaryButton(label: l.rcNeedProfileAction, onPressed: open),
      );
    case RecStatus.empty:
      return make(Icons.search_off, l.rcEmptyTitle, l.rcEmptyBody);
    case RecStatus.failure:
      return make(Icons.error_outline, l.errorTitle, l.errorBody, error: true);
    case RecStatus.idle:
    case RecStatus.loading:
    case RecStatus.notConfigured:
    case RecStatus.ready:
      return null;
  }
}

/// The Home section: the best three, hidden jobs left out. Draws nothing until there is something worth saying (signed out, or not configured).
class RecommendationsSection extends StatelessWidget {
  const RecommendationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<RecommendationsCubit, RecommendationsState>(
      builder: (context, s) => BlocBuilder<HiddenJobsCubit, HiddenJobsState>(
        builder: (context, hidden) {
          if (s.status == RecStatus.idle ||
              s.status == RecStatus.notConfigured) {
            return const SizedBox.shrink();
          }
          final items = [
            for (final r in s.items)
              if (!hidden.isHidden(r.job)) r,
          ];
          Widget body;
          if (s.status == RecStatus.loading && items.isEmpty) {
            body = const SizedBox(
              height: 200,
              child: OrbiSkeletonList(count: 2),
            );
          } else {
            final message = items.isEmpty
                ? recommendationsMessage(context, s, compact: true)
                : null;
            body =
                message ??
                OrbiAdaptiveGrid(
                  children: [
                    for (final r in items.take(3)) RecommendedJobTile(rec: r),
                  ],
                );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OrbiSectionHeader(
                  title: l.rcTitle,
                  actionLabel: items.length > 3 ? l.rcSeeAll : null,
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecommendationsPage(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s3),
                body,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Every recommendation, with the reasons for each.
class RecommendationsPage extends StatelessWidget {
  const RecommendationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.rcTitle)),
      body: BlocBuilder<RecommendationsCubit, RecommendationsState>(
        builder: (context, s) => BlocBuilder<HiddenJobsCubit, HiddenJobsState>(
          builder: (context, hidden) {
            final items = [
              for (final r in s.items)
                if (!hidden.isHidden(r.job)) r,
            ];
            final message = items.isEmpty
                ? recommendationsMessage(context, s)
                : null;
            if (message != null) return message;
            if (items.isEmpty) return const OrbiPageLoading();
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  children: [
                    Text(l.rcSubtitle, style: context.metadataStyle),
                    if (s.thin) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(l.rcThinNote, style: context.metadataStyle),
                    ],
                    const SizedBox(height: AppSpace.s3),
                    for (final r in items) ...[
                      RecommendedJobTile(rec: r, compact: false),
                      const SizedBox(height: AppSpace.s4),
                    ],
                    Text(l.rcDisclaimer, style: context.metadataStyle),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
