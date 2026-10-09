import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/auth_failure.dart';
import 'auth_cubit.dart';

/// Localised message for a failure kind (never the raw server text).
String authFailureText(AppLocalizations l, AuthFailureKind k) => switch (k) {
  AuthFailureKind.invalidCredentials => l.authErrorInvalidCredentials,
  AuthFailureKind.emailNotConfirmed => l.authErrorEmailNotConfirmed,
  AuthFailureKind.emailAlreadyRegistered => l.authErrorEmailTaken,
  AuthFailureKind.invalidEmail => l.authErrorInvalidEmail,
  AuthFailureKind.weakPassword => l.authErrorWeakPassword,
  AuthFailureKind.rateLimited => l.authErrorRateLimited,
  AuthFailureKind.network => l.authErrorNetwork,
  AuthFailureKind.unavailable => l.authErrorUnavailable,
  AuthFailureKind.unknown => l.authErrorUnknown,
};

/// Sign in / create account. Closes itself when a session appears.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final c = context.read<AuthCubit>();
    _signUp
        ? c.signUp(_email.text, _password.text)
        : c.signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (a, b) => !a.signedIn && b.signedIn,
      listener: (context, s) => Navigator.of(context).maybePop(),
      builder: (context, s) => Scaffold(
        appBar: AppBar(
          title: Text(_signUp ? l.authSignUpTitle : l.authSignInTitle),
          leading: const BackButton(),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s4),
                children: [
                  TextFormField(
                    controller: _email,
                    enabled: !s.busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l.authEmail),
                    validator: (v) =>
                        _validEmail(v ?? '') ? null : l.authEmailInvalid,
                  ),
                  const SizedBox(height: AppSpace.s3),
                  TextFormField(
                    controller: _password,
                    enabled: !s.busy,
                    obscureText: true,
                    autofillHints: [
                      _signUp
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(labelText: l.authPassword),
                    validator: (v) =>
                        (v ?? '').length >= 8 ? null : l.authPasswordShort,
                  ),
                  if (s.failure != null || s.notice != AuthNotice.none) ...[
                    const SizedBox(height: AppSpace.s3),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        s.failure != null
                            ? authFailureText(l, s.failure!)
                            : (s.notice == AuthNotice.confirmationSent
                                  ? l.authConfirmationSent
                                  : l.authResetSent),
                        style: context.text.bodyMedium!.copyWith(
                          color: s.failure != null ? c.error : c.ink,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s4),
                  AppButton(
                    label: _signUp ? l.authSignUpAction : l.authSignInAction,
                    loading: s.busy,
                    expand: true,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpace.s2),
                  AppButton(
                    label: _signUp
                        ? l.authSwitchToSignIn
                        : l.authSwitchToSignUp,
                    variant: AppButtonVariant.tertiary,
                    expand: true,
                    onPressed: s.busy
                        ? null
                        : () => setState(() => _signUp = !_signUp),
                  ),
                  if (!_signUp)
                    AppButton(
                      label: l.authForgotPassword,
                      variant: AppButtonVariant.tertiary,
                      expand: true,
                      onPressed: s.busy
                          ? null
                          : () {
                              if (_validEmail(_email.text)) {
                                context.read<AuthCubit>().resetPassword(
                                  _email.text,
                                );
                              } else {
                                _form.currentState?.validate();
                              }
                            },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
