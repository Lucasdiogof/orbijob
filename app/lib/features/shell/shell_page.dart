import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../applications/applications_page.dart';
import '../favorites/favorites_page.dart';
import '../home/home_page.dart';
import '../search/presentation/pages/search_page.dart';

/// Main navigation: Home, Explore, Favorites, Applications. Profile lives in the header.
/// Adaptive: bottom bar on compact widths, rail from 600dp.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final destinations = [
      (Icons.home_outlined, Icons.home, l.navHome),
      (Icons.travel_explore_outlined, Icons.travel_explore, l.navExplore),
      (Icons.favorite_border, Icons.favorite, l.navFavorites),
      (Icons.assignment_outlined, Icons.assignment, l.navApplications),
    ];
    const pages = [
      HomePage(),
      SearchPage(),
      FavoritesPage(),
      ApplicationsPage(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 600;

    final appBar = AppBar(
      title: Text(l.appTitle),
      actions: [
        IconButton(
          tooltip: l.profile,
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l.profileSoon))),
        ),
      ],
    );
    final body = IndexedStack(index: _index, children: pages);

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: Text(d.$3),
                  ),
              ],
            ),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}
