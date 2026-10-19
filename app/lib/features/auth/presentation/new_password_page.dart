import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/orbi/orbi.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_cubit.dart';
import 'auth_page.dart';

/// The only screen while a recovery session waits for its new password ([AuthGate]). It cannot be left except by saving a new password
/// (then the temporary session is closed and the login opens) or cancelling (which closes the temporary session): the recovery session is
/// never used as a sign-in.
class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key});
  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeat = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, s) => PopScope(
        // Only closable once recovery is over (password saved or cancelled).
        canPop: !s.recovering,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l.authNewPasswordTitle),
            automaticallyImplyLeading: false,
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
                        headline: l.authNewPasswordTitle,
                        subtitle: l.authNewPasswordSubtitle,
                      ),
                      const SizedBox(height: AppSpace.s6),
                      PasswordField(
                        label: l.authNewPasswordLabel,
                        controller: _password,
                        enabled: !s.busy,
                        newPassword: true,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v ?? '').length >= 8 ? null : l.authPasswordShort,
                      ),
                      const SizedBox(height: AppSpace.s3),
                      PasswordField(
                        label: l.authNewPasswordRepeat,
                        controller: _repeat,
                        enabled: !s.busy,
                        newPassword: true,
                        onSubmitted: (_) => _submit(context),
                        validator: (v) =>
                            v == _password.text ? null : l.authPasswordMismatch,
                      ),
                      if (s.failure != null) ...[
                        const SizedBox(height: AppSpace.s3),
                        AuthMessage(
                          error: true,
                          text: authFailureText(l, s.failure!),
                        ),
                      ],
                      const SizedBox(height: AppSpace.s5),
                      OrbiPrimaryButton(
                        label: l.authNewPasswordAction,
                        loading: s.busy,
                        expand: true,
                        onPressed: () => _submit(context),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      OrbiTextButton(
                        label: l.authCancelRecovery,
                        onPressed: s.busy
                            ? null
                            : () => context.read<AuthCubit>().cancelRecovery(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (_form.currentState?.validate() ?? false) {
      context.read<AuthCubit>().updatePassword(_password.text);
    }
  }
}
