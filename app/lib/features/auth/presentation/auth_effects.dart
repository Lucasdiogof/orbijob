import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/auth_failure.dart';
import 'auth_cubit.dart';
import 'auth_page.dart';

/// Reacts to session events with UI, once per event: a session that ended on its own, an expired e-mail link, and a password that was
/// changed by a recovery (the login screen opens with the confirmation). It never opens the recovery form: that is [AuthGate]'s job, driven by
/// the state, so no later state change (a busy flag during an account deletion, a late callback) can bring an old recovery back.
///
/// Mounted by [AuthGate] on the first route, which is never popped and survives every change of account.
class AuthEffects extends StatelessWidget {
  const AuthEffects({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, AuthState>(
    // only transitions: the same notice or failure emitted again with another field is not a new event
    listenWhen: (a, b) =>
        (a.notice != b.notice && b.notice != AuthNotice.none) ||
        (a.failure != b.failure && b.failure == AuthFailureKind.linkInvalid),
    listener: (context, s) {
      final l = AppLocalizations.of(context);
      final cubit = context.read<AuthCubit>();
      // An expired / reused e-mail link arrives outside any form: say so instead of leaving it for later.
      if (s.failure == AuthFailureKind.linkInvalid) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(authFailureText(l, s.failure!))),
          );
        cubit.dismissMessage();
        return;
      }
      if (s.notice == AuthNotice.sessionExpired) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(authNoticeText(l, s.notice))));
        cubit.dismissMessage();
        return;
      }
      if (s.notice == AuthNotice.passwordChanged && !s.signedIn) {
        // the recovery ended with the new password saved and its temporary session closed: sign in with the new password
        cubit.dismissMessage();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const AuthPage(initialNotice: AuthNotice.passwordChanged),
          ),
        );
      }
    },
    child: child,
  );
}
