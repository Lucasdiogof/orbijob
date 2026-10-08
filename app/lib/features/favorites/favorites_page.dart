import 'package:flutter/material.dart';

import '../../core/widgets/state_message.dart';
import '../../l10n/app_localizations.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StateMessage(
      icon: Icons.favorite_border,
      title: l.favoritesTitle,
      body: l.favoritesBody,
    );
  }
}
