import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_cubit.dart';
import 'auth_page.dart';

/// Shown after the user opens a password-recovery link. It cannot be dismissed except by choosing a new
/// password or cancelling (which closes the temporary session), so the recovery session is never used as a login.
class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key});
  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
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
                      controller: _password,
                      enabled: !s.busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(context),
                      decoration: InputDecoration(
                        labelText: l.authNewPasswordLabel,
                      ),
                      validator: (v) =>
                          (v ?? '').length >= 8 ? null : l.authPasswordShort,
                    ),
                    if (s.failure != null) ...[
                      const SizedBox(height: AppSpace.s3),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          authFailureText(l, s.failure!),
                          style: context.text.bodyMedium!.copyWith(
                            color: context.colors.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.s4),
                    AppButton(
                      label: l.authNewPasswordAction,
                      loading: s.busy,
                      expand: true,
                      onPressed: () => _submit(context),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    AppButton(
                      label: l.authCancelRecovery,
                      variant: AppButtonVariant.tertiary,
                      expand: true,
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
    );
  }

  void _submit(BuildContext context) {
    if (_form.currentState?.validate() ?? false) {
      context.read<AuthCubit>().updatePassword(_password.text);
    }
  }
}
