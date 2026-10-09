import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design.dart';
import '../../core/theme_cubit.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/state_view.dart';
import '../../l10n/app_localizations.dart';

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
