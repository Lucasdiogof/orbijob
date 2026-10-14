import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/di/injector.dart';
import '../../../core/open_link.dart';
import '../../../core/orbi/orbi.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_page.dart' show PasswordField;
import '../domain/account_data_repository.dart';
import 'data_export_cubit.dart';

/// "Your data" on the privacy screen: export a copy, delete the account, and the public documents. Export and deletion need an account.
class YourDataSection extends StatelessWidget {
  const YourDataSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final signedIn = context.select((AuthCubit a) => a.state.signedIn);
    return BlocProvider(
      create: (_) => DataExportCubit(
        maybe<AccountDataRepository>(),
        share: maybe<DataFileShare>(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.pdTitle, style: context.text.titleMedium),
          const SizedBox(height: AppSpace.s1),
          Text(
            l.pdIntro,
            style: context.text.bodyMedium!.copyWith(color: c.muted),
          ),
          const SizedBox(height: AppSpace.s3),
          if (!signedIn)
            OrbiCard(
              child: Text(l.pdSignInHint, style: context.text.bodyMedium),
            )
          else ...[
            const _ExportCard(),
            const SizedBox(height: AppSpace.s3),
            const _DeleteCard(),
          ],
          const SizedBox(height: AppSpace.s3),
          const _Documents(),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return BlocBuilder<DataExportCubit, DataExportState>(
      builder: (context, s) {
        final working = s.phase == ExportPhase.working;
        final (String? message, Color tint) = switch (s.phase) {
          ExportPhase.working => (l.pdExportWorking, c.muted),
          ExportPhase.done => (
            s.resumeFilesMissing > 0
                ? '${l.pdExportDone}\n${l.pdExportMissing(s.resumeFilesMissing)}'
                : l.pdExportDone,
            c.success,
          ),
          ExportPhase.failed => (l.pdExportFailed, c.error),
          ExportPhase.idle => (null, c.muted),
        };
        return OrbiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.download_rounded, color: c.primary),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text(
                      l.pdExportTitle,
                      style: context.text.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s2),
              Text(
                l.pdExportBody,
                style: context.text.bodyMedium!.copyWith(color: c.muted),
              ),
              const SizedBox(height: AppSpace.s3),
              OrbiSecondaryButton(
                label: l.pdExportAction,
                icon: Icons.archive_outlined,
                loading: working,
                onPressed: working
                    ? null
                    : () => context.read<DataExportCubit>().start(),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpace.s2),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: context.text.bodySmall!.copyWith(color: tint),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DeleteCard extends StatelessWidget {
  const _DeleteCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return OrbiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delete_forever_outlined, color: c.error),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(l.pdDeleteTitle, style: context.text.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l.pdDeleteBody,
            style: context.text.bodyMedium!.copyWith(color: c.muted),
          ),
          const SizedBox(height: AppSpace.s3),
          OrbiSecondaryButton(
            label: l.pdDeleteTitle,
            icon: Icons.delete_outline_rounded,
            onPressed: () => _confirm(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final auth = context.read<AuthCubit>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          BlocProvider.value(value: auth, child: const DeleteAccountDialog()),
    );
  }
}

/// The explicit confirmation: what goes, what stays, an acknowledgement and the current password. After the server deleted the account the
/// dialog turns into the confirmation ("deleted") and only its button ends the session: a message shown after the sign-out would be lost with
/// the screens that the sign-out tears down.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _understood = false;
  bool _busy = false;
  bool _done = false;
  AuthFailureKind? _failure;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _ready => _understood && _password.text.isNotEmpty && !_busy;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    final cubit = context.read<AuthCubit>();
    await cubit.deleteAccount(_password.text);
    if (!mounted) return;
    final failure = cubit.state.failure;
    if (failure == null) {
      setState(() {
        _busy = false;
        _done = true;
      });
      return;
    }
    cubit.dismissMessage();
    setState(() {
      _busy = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    if (_done) {
      return PopScope(
        canPop: false,
        child: OrbiDialog(
          title: l.pdDeleted,
          message: l.pdDeletedBody,
          actions: [
            OrbiPrimaryButton(
              label: l.pdDeletedAction,
              onPressed: () async {
                final nav = Navigator.of(context);
                await context.read<AuthCubit>().finishAccountDeletion();
                if (nav.mounted && nav.canPop()) nav.pop();
              },
            ),
          ],
        ),
      );
    }
    final items = [
      l.pdDelete1,
      l.pdDelete2,
      l.pdDelete3,
      l.pdDelete4,
      l.pdDelete5,
    ];
    return OrbiDialog(
      title: l.pdDeleteTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.pdDeleteBody, style: context.text.bodyMedium),
          const SizedBox(height: AppSpace.s3),
          Text(l.pdDeleteWhatTitle, style: context.text.labelLarge),
          const SizedBox(height: AppSpace.s1),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: AppSpace.s2),
                    child: Icon(Icons.circle, size: 5, color: c.muted),
                  ),
                  Expanded(child: Text(i, style: context.text.bodySmall)),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l.pdDeleteKeeps,
            style: context.text.bodySmall!.copyWith(color: c.muted),
          ),
          const SizedBox(height: AppSpace.s3),
          PasswordField(
            controller: _password,
            label: l.pdDeletePassword,
            enabled: !_busy,
            validator: (_) => null,
            onSubmitted: (_) {
              if (_ready) _delete();
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _understood,
            onChanged: _busy
                ? null
                : (v) => setState(() => _understood = v ?? false),
            title: Text(l.pdDeleteConfirmCheck, style: context.text.bodyMedium),
          ),
          if (_failure != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _failure == AuthFailureKind.invalidCredentials
                    ? l.pdDeleteWrongPassword
                    : l.pdDeleteFailed,
                style: context.text.bodySmall!.copyWith(color: c.error),
              ),
            ),
        ],
      ),
      actions: [
        OrbiTextButton(
          label: l.commonCancel,
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        Material(
          color: _ready ? c.error : c.line,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _ready ? _delete : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSize.touch),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
                child: Center(
                  widthFactor: 1,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          l.pdDeleteAction,
                          style: context.text.labelLarge!.copyWith(
                            color: _ready ? c.onError : c.muted,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Public documents of the product (published on the company site).
const orbiPrivacyUrl = 'https://lucksrei.com/projects/orbijob/privacy/';
const orbiTermsUrl = 'https://lucksrei.com/projects/orbijob/terms/';
const orbiDeletionUrl = 'https://lucksrei.com/projects/orbijob/data-deletion/';

class _Documents extends StatelessWidget {
  const _Documents();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget link(String label, String url) => ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.open_in_new_rounded, size: 20),
      title: Text(label),
      onTap: () => openExternalLink(url),
    );
    return Column(
      children: [
        link(l.pdLinkPrivacy, orbiPrivacyUrl),
        link(l.pdLinkTerms, orbiTermsUrl),
        link(l.pdLinkDeletion, orbiDeletionUrl),
      ],
    );
  }
}
