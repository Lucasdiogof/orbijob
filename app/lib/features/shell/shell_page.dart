import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design.dart';
import '../../core/widgets/app_navigation.dart';
import '../../l10n/app_localizations.dart';
import '../applications/applications_page.dart';
import '../favorites/favorites_page.dart';
import '../home/home_page.dart';
import '../profile/profile_page.dart';
import '../search/presentation/pages/search_page.dart';
import 'shell_cubit.dart';

/// Main navigation: Home, Explore, Favorites, Applications; the profile lives in the header.
/// Compact (<600): bottom bar. Wider: side rail (labels hidden in short landscape windows, extended from 1024).
class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  static const _pages = <Widget>[
    HomePage(),
    SearchPage(),
    FavoritesPage(),
    ApplicationsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final destinations = [
      AppDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l.navHome,
      ),
      AppDestination(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        label: l.navExplore,
      ),
      AppDestination(
        icon: Icons.favorite_border,
        selectedIcon: Icons.favorite,
        label: l.navFavorites,
      ),
      AppDestination(
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        label: l.navApplications,
      ),
    ];
    return BlocBuilder<ShellCubit, ShellState>(
      builder: (context, shell) {
        final size = MediaQuery.sizeOf(context);
        final window = WindowClass.of(size.width);
        final body = IndexedStack(index: shell.index, children: _pages);
        final appBar = AppBar(
          titleSpacing: AppSpace.s4,
          title: const BrandLogo(height: 24),
          actions: [
            IconButton(
              tooltip: l.profile,
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
              ),
            ),
            const SizedBox(width: AppSpace.s1),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(color: context.colors.divider, height: 1),
          ),
        );
        if (window == WindowClass.compact) {
          return Scaffold(
            appBar: appBar,
            body: body,
            bottomNavigationBar: AppNavBar(
              destinations: destinations,
              selectedIndex: shell.index,
              onSelected: context.read<ShellCubit>().goTo,
              semanticLabel: l.navMain,
            ),
          );
        }
        final shortLandscape = size.height < 480;
        return Scaffold(
          appBar: appBar,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppNavRail(
                destinations: destinations,
                selectedIndex: shell.index,
                onSelected: context.read<ShellCubit>().goTo,
                extended: window == WindowClass.expanded,
                showLabels: !shortLandscape,
                semanticLabel: l.navMain,
              ),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
