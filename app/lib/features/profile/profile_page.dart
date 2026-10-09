import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design.dart';
import '../../core/theme_cubit.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/state_view.dart';
import '../../l10n/app_localizations.dart';
import '../auth/presentation/auth_cubit.dart';
import '../auth/presentation/auth_page.dart';

/// Profile entry (reached from the header). The professional profile itself is not built yet; appearance is.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.profileTitle),
        leading: const BackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: context.colors.divider, height: 1),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: [
              SectionHeader(title: l.accountTitle),
              const SizedBox(height: AppSpace.s3),
              const _AccountSection(),
              const SizedBox(height: AppSpace.s6),
              SectionHeader(title: l.appearanceTitle),
              const SizedBox(height: AppSpace.s3),
              BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, mode) => SegmentedButton<ThemeMode>(
                  showSelectedIcon: true,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto_outlined),
                      label: Text(l.themeSystem),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_outlined),
                      label: Text(l.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_outlined),
                      label: Text(l.themeDark),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) =>
                      context.read<ThemeCubit>().select(s.first),
                ),
              ),
              const SizedBox(height: AppSpace.s6),
              SizedBox(
                height: 260,
                child: StateView(
                  icon: Icons.person_outline,
                  title: l.profileEmptyTitle,
                  body: l.profileEmptyBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, s) {
        final String title;
        final String body;
        Widget? action;
        if (!s.available) {
          title = l.accountUnavailableTitle;
          body = l.accountUnavailableBody;
        } else if (s.signedIn) {
          title = s.user!.email == null
              ? l.accountSignedInNoEmail
              : l.accountSignedInAs(s.user!.email!);
          body = '';
          action = AppButton(
            label: l.accountSignOut,
            variant: AppButtonVariant.secondary,
            loading: s.busy,
            onPressed: () => context.read<AuthCubit>().signOut(),
          );
        } else {
          title = l.accountSignIn;
          body = l.accountSignedOutBody;
          action = AppButton(
            label: l.accountSignIn,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const AuthPage())),
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: c.cardBg,
            border: Border.all(color: c.cardBorder),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s1),
                  Text(body, style: t.bodyMedium!.copyWith(color: c.muted)),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpace.s3),
                  action,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
