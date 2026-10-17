import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design.dart';
import '../../core/orbi/orbi.dart';
import '../../l10n/app_localizations.dart';
import '../applications/applications_page.dart';
import '../auth/presentation/auth_cubit.dart';
import '../compare/compare_page.dart';
import '../favorites/favorites_page.dart';
import '../home/home_page.dart';
import '../notifications/presentation/notifications_bell.dart';
import '../profile/profile_page.dart';
import '../search/presentation/pages/search_page.dart';
import 'shell_cubit.dart';

/// Main navigation: Home, Explore, Favorites, Applications; the profile is one tap away in the top bar (compact) or at the foot of the
/// side navigation (wider windows). Compact (< 600): top bar + bottom bar. Medium: icon rail. Expanded (>= 1024): extended side navigation.
class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  static const _pages = <Widget>[
    HomePage(),
    SearchPage(),
    FavoritesPage(),
    ApplicationsPage(),
  ];

  void _openProfile(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ProfilePage()));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final destinations = [
      OrbiDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: l.navHome,
      ),
      OrbiDestination(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
        label: l.navExplore,
      ),
      OrbiDestination(
        icon: Icons.bookmark_border_rounded,
        selectedIcon: Icons.bookmark_rounded,
        label: l.navFavorites,
      ),
      OrbiDestination(
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment_rounded,
        label: l.navApplications,
      ),
    ];
    return BlocBuilder<ShellCubit, ShellState>(
      builder: (context, shell) {
        final size = MediaQuery.sizeOf(context);
        final window = WindowClass.of(size.width);
        final auth = context.watch<AuthCubit>().state;
        final initial = auth.user?.email?.isNotEmpty == true
            ? auth.user!.email!.substring(0, 1)
            : null;
        final body = IndexedStack(index: shell.index, children: _pages);
        if (window == WindowClass.compact) {
          return Scaffold(
            appBar: OrbiTopBar(
              brand: const BrandLogo(height: 24),
              actions: [
                const NotificationsBell(),
                OrbiProfileButton(
                  tooltip: l.profile,
                  initial: initial,
                  onPressed: () => _openProfile(context),
                ),
              ],
            ),
            body: body,
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CompareBar(),
                OrbiNavigationBar(
                  destinations: destinations,
                  selectedIndex: shell.index,
                  onSelected: context.read<ShellCubit>().goTo,
                  semanticLabel: l.navMain,
                ),
              ],
            ),
          );
        }
        final extended = window == WindowClass.expanded;
        final shortLandscape = size.height < 480;
        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrbiSideNav(
                destinations: destinations,
                selectedIndex: shell.index,
                onSelected: context.read<ShellCubit>().goTo,
                extended: extended,
                showLabels: !shortLandscape,
                semanticLabel: l.navMain,
                leading: extended
                    ? const BrandLogo(height: 26)
                    : const BrandSymbol(size: 32),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const NotificationsBell(),
                    OrbiProfileButton(
                      tooltip: l.profile,
                      initial: initial,
                      extendedLabel: extended ? l.profile : null,
                      onPressed: () => _openProfile(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: SafeArea(left: false, child: body)),
                    const CompareBar(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
