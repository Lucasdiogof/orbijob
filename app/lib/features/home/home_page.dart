import 'package:flutter/material.dart';

import '../../core/widgets/state_message.dart';
import '../../l10n/app_localizations.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StateMessage(
      icon: Icons.home_outlined,
      title: l.homeTitle,
      body: l.homeBody,
    );
  }
}
