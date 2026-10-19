import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/orbi/orbi.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_cubit.dart';
import 'auth_page.dart';

/// Password recovery by a 6-digit code typed in the app (no link, no deep link): e-mail -> code -> new password.
/// When the code is accepted the cubit flags [AuthState.recovering] and [AuthEffects] opens the new-password screen.
class RecoveryCodePage extends StatefulWidget {
  const RecoveryCodePage({super.key, this.initialEmail = ''});
  final String initialEmail;
  @override
  State<RecoveryCodePage> createState() => _RecoveryCodePageState();
}

class _RecoveryCodePageState extends State<RecoveryCodePage> {
  static const resendWait = 60;
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  bool _codeStep = false;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  bool _validEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

  void _startWait() {
    _timer?.cancel();
    setState(() => _wait = resendWait);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    if (_codeStep ? false : !(_form.currentState?.validate() ?? false)) return;
    final c = context.read<AuthCubit>();
    await c.resetPassword(_email.text);
    // A rate-limit or network failure keeps the person on the same step so they can try again.
    if (!mounted || c.state.failure != null) return;
    setState(() => _codeStep = true);
    _startWait();
  }

  void _verify() {
    if (!(_form.currentState?.validate() ?? false)) return;
    context.read<AuthCubit>().verifyRecoveryCode(_email.text, _code.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (a, b) =>
          (!a.signedIn && b.signedIn) || (!a.recovering && b.recovering),
      // Remove this route only: the new-password screen may already be on top of it.
      listener: (context, s) {
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      },
      builder: (context, s) => Scaffold(
        appBar: AppBar(
          title: Text(l.authRecoveryTitle),
          leading: const BackButton(),
        ),
        body: OrbitBackdrop(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpace.s5),
                  children: [
                    AuthHeader(
                      headline: l.authRecoveryTitle,
                      subtitle: _codeStep
                          ? l.authRecoveryEnterCode(_email.text.trim())
                          : l.authRecoverySubtitle,
                    ),
                    const SizedBox(height: AppSpace.s6),
                    if (!_codeStep)
                      OrbiTextField(
                        label: l.authEmail,
                        controller: _email,
                        enabled: !s.busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _send(),
                        validator: (v) =>
                            _validEmail(v ?? '') ? null : l.authEmailInvalid,
                      )
                    else
                      OrbiTextField(
                        label: l.authRecoveryCodeLabel,
                        controller: _code,
                        enabled: !s.busy,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        textInputAction: TextInputAction.done,
                        maxLength: 6,
                        // a one-time code reads as a code: large, centred, widely tracked, with the six places hinted
                        textAlign: TextAlign.center,
                        hint: '······',
                        textStyle: context.text.headlineSmall!.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          letterSpacing: 10,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onSubmitted: (_) => _verify(),
                        validator: (v) => (v ?? '').trim().length == 6
                            ? null
                            : l.authRecoveryCodeShort,
                      ),
                    if (s.failure != null ||
                        (_codeStep && s.notice == AuthNotice.resetSent)) ...[
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
                      label: _codeStep
                          ? l.authRecoveryVerify
                          : l.authRecoverySendCode,
                      loading: s.busy,
                      expand: true,
                      onPressed: _codeStep ? _verify : _send,
                    ),
                    if (_codeStep) ...[
                      const SizedBox(height: AppSpace.s2),
                      OrbiTextButton(
                        label: _wait > 0
                            ? l.authRecoveryResendIn(_wait)
                            : l.authRecoveryResend,
                        onPressed: s.busy || _wait > 0 ? null : _send,
                      ),
                      OrbiTextButton(
                        label: l.authRecoveryChangeEmail,
                        onPressed: s.busy
                            ? null
                            : () {
                                _timer?.cancel();
                                _code.clear();
                                context.read<AuthCubit>().dismissMessage();
                                setState(() {
                                  _codeStep = false;
                                  _wait = 0;
                                });
                              },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
