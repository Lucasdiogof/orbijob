import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import 'notifications_cubit.dart';
import 'notifications_page.dart';

/// The bell of the top bar / side navigation: opens the notification centre and shows how many are unread. Signed out (or without a backend) it
/// still opens the centre, which then explains what an account adds.
class NotificationsBell extends StatelessWidget {
  const NotificationsBell({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      buildWhen: (a, b) => a.unread != b.unread,
      builder: (context, s) {
        final n = s.unread;
        final label = n == 0 ? l.ntBell : l.ntBellUnread(n);
        return Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: IconButton(
            tooltip: label,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsPage(),
              ),
            ),
            icon: Badge(
              isLabelVisible: n > 0,
              // a count in a small badge: capped text scaling keeps it from covering the neighbouring profile button
              label: Text(
                n > 99 ? '99+' : '$n',
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: 1.2),
              ),
              child: Icon(
                n > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
              ),
            ),
          ),
        );
      },
    );
  }
}
