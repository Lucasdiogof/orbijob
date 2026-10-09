import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import 'auth_cubit.dart';
import 'auth_page.dart';
import 'new_password_page.dart';

/// Reacts to session events with UI: opens the new-password screen after a recovery link and reports a session
/// that ended or a password that changed. Mounted once, around the signed-in shell.
class AuthEffects extends StatefulWidget {
  const AuthEffects({super.key, required this.child});
  final Widget child;
  @override
  State<AuthEffects> createState() => _AuthEffectsState();
}

class _AuthEffectsState extends State<AuthEffects> {
  bool _recoveryOpen = false;

  @override
  void initState() {
    super.initState();
    // A recovery link restores a session, which rebuilds the app: the flag may already be set on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<AuthCubit>().state.recovering) {
        _openRecovery();
      }
    });
  }

  void _openRecovery() {
    if (_recoveryOpen) return;
    _recoveryOpen = true;
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const NewPasswordPage()))
        .whenComplete(() => _recoveryOpen = false);
  }

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, AuthState>(
    listener: (context, s) {
      if (s.recovering) {
        _openRecovery();
        return;
      }
      if (_recoveryOpen) {
        _recoveryOpen = false;
        Navigator.of(context).pop();
      }
      final l = AppLocalizations.of(context);
      if (s.notice == AuthNotice.sessionExpired ||
          s.notice == AuthNotice.passwordChanged) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(authNoticeText(l, s.notice))));
        context.read<AuthCubit>().dismissMessage();
      }
    },
    child: widget.child,
  );
}
