import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/orbi/orbi.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/auth_failure.dart';
import 'auth_cubit.dart';
import 'recovery_code_page.dart';

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
  AuthFailureKind.samePassword => l.authErrorSamePassword,
  AuthFailureKind.linkInvalid => l.authErrorLinkInvalid,
  AuthFailureKind.codeInvalid => l.authErrorCodeInvalid,
  AuthFailureKind.unknown => l.authErrorUnknown,
};

/// Localised text for an informational notice.
String authNoticeText(AppLocalizations l, AuthNotice n) => switch (n) {
  AuthNotice.confirmationSent => l.authConfirmationSent,
  AuthNotice.resetSent => l.authResetSent,
  AuthNotice.passwordChanged => l.authPasswordChanged,
  AuthNotice.sessionExpired => l.authSessionExpired,
  AuthNotice.none => '',
};

/// A password field with a show/hide toggle (sign in, sign up, new password).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.enabled,
    required this.validator,
    this.newPassword = false,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool newPassword;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OrbiTextField(
      label: widget.label,
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: !_visible,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      validator: widget.validator,
      suffix: IconButton(
        tooltip: _visible ? l.authHidePassword : l.authShowPassword,
        icon: Icon(
          _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: () => setState(() => _visible = !_visible),
      ),
    );
  }
}

/// The short brand header of the account screens: symbol, headline and one calm line below.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.headline, required this.subtitle});
  final String headline;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandSymbol(size: 44),
        const SizedBox(height: AppSpace.s5),
        Semantics(
          header: true,
          child: Text(headline, style: context.text.headlineMedium),
        ),
        const SizedBox(height: AppSpace.s2),
        Text(
          subtitle,
          style: context.text.bodyMedium!.copyWith(color: c.muted),
        ),
      ],
    );
  }
}

/// A failure or notice from the account flow, announced to screen readers.
class AuthMessage extends StatelessWidget {
  const AuthMessage({super.key, required this.text, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = error ? c.onErrorContainer : c.onPrimaryContainer;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: error ? c.errorContainer : c.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.mark_email_read_outlined,
                size: AppSize.iconSm,
                color: fg,
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(
                  text,
                  style: context.text.bodyMedium!.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sign in / create account. Closes itself when a session appears.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.startAsSignUp = false});

  /// Opens on the "create account" form (from a gate that says "Create account").
  final bool startAsSignUp;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _signUp = widget.startAsSignUp;

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
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (a, b) => !a.signedIn && b.signedIn,
      // Remove this route only: the new-password screen may already be on top after a code recovery.
      listener: (context, s) {
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      },
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
                padding: const EdgeInsets.all(AppSpace.s5),
                children: [
                  AuthHeader(
                    headline: _signUp
                        ? l.authSignUpHeadline
                        : l.authSignInHeadline,
                    subtitle: _signUp
                        ? l.authSignUpSubtitle
                        : l.authSignInSubtitle,
                  ),
                  const SizedBox(height: AppSpace.s6),
                  OrbiTextField(
                    label: l.authEmail,
                    controller: _email,
                    enabled: !s.busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        _validEmail(v ?? '') ? null : l.authEmailInvalid,
                  ),
                  const SizedBox(height: AppSpace.s4),
                  PasswordField(
                    label: l.authPassword,
                    controller: _password,
                    enabled: !s.busy,
                    newPassword: _signUp,
                    onSubmitted: (_) => _submit(),
                    validator: (v) =>
                        (v ?? '').length >= 8 ? null : l.authPasswordShort,
                  ),
                  if (!_signUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: OrbiTextButton(
                        label: l.authForgotPassword,
                        onPressed: s.busy
                            ? null
                            : () {
                                context.read<AuthCubit>().dismissMessage();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => RecoveryCodePage(
                                      initialEmail: _email.text.trim(),
                                    ),
                                  ),
                                );
                              },
                      ),
                    ),
                  if (s.failure != null || s.notice != AuthNotice.none) ...[
                    const SizedBox(height: AppSpace.s3),
                    AuthMessage(
                      error: s.failure != null,
                      text: s.failure != null
                          ? authFailureText(l, s.failure!)
                          : authNoticeText(l, s.notice),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s5),
                  OrbiPrimaryButton(
                    label: _signUp ? l.authSignUpAction : l.authSignInAction,
                    loading: s.busy,
                    expand: true,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpace.s2),
                  OrbiTextButton(
                    label: _signUp
                        ? l.authSwitchToSignIn
                        : l.authSwitchToSignUp,
                    onPressed: s.busy
                        ? null
                        : () => setState(() => _signUp = !_signUp),
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
