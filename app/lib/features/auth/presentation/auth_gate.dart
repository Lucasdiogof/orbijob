import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shell/shell_page.dart';
import 'auth_cubit.dart';
import 'auth_effects.dart';
import 'new_password_page.dart';

/// The first screen of the app. While a recovery session waits for its new password the ONLY screen is the new-password form: the Home and
/// every account screen are unreachable, whatever order the server's sign-in event and the code check arrive in. When the recovery starts,
/// the screens stacked on top (login, recovery code) are removed so nothing covers the form.
///
/// This route is never popped, so [AuthEffects] here outlives every change of account (a listener inside the account scope would miss the
/// events that happen during the switch).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.home = const ShellPage()});

  /// The first screen when no recovery is pending (the app shell; a stand-in in tests).
  final Widget home;

  @override
  Widget build(BuildContext context) => AuthEffects(
    child: BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (a, b) => !a.recovering && b.recovering,
      listener: (context, _) =>
          Navigator.of(context).popUntil((r) => r.isFirst),
      buildWhen: (a, b) => a.recovering != b.recovering,
      builder: (context, s) => s.recovering ? const NewPasswordPage() : home,
    ),
  );
}
