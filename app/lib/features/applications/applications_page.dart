import 'package:flutter/material.dart';

import '../../core/widgets/state_message.dart';
import '../../l10n/app_localizations.dart';

class ApplicationsPage extends StatelessWidget {
  const ApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StateMessage(
      icon: Icons.assignment_outlined,
      title: l.applicationsTitle,
      body: l.applicationsBody,
    );
  }
}
