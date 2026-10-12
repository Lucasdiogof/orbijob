import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/design.dart';
import 'orbi_buttons.dart';

enum OrbiSnackKind { info, success, error }

/// Short, floating confirmation. One at a time; announced to screen readers; an optional action (Undo, Retry).
void showOrbiSnackBar(
  BuildContext context,
  String message, {
  OrbiSnackKind kind = OrbiSnackKind.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final c = context.colors;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final (icon, tint) = switch (kind) {
    OrbiSnackKind.success => (Icons.check_circle_rounded, c.success),
    OrbiSnackKind.error => (Icons.error_rounded, c.error),
    OrbiSnackKind.info => (Icons.info_rounded, c.primary),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: c.container,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: c.line),
        ),
        content: Row(
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium!.copyWith(color: c.ink),
              ),
            ),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: c.primary,
                onPressed: onAction ?? () {},
              ),
      ),
    );
}

/// Confirmation dialog with a clear primary action. [destructive] paints the confirm button in the error colour.
Future<bool> showOrbiConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => OrbiDialog(
      title: title,
      message: message,
      actions: [
        OrbiTextButton(
          label: cancelLabel ?? l.commonCancel,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        destructive
            ? _DestructiveButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              )
            : OrbiPrimaryButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
      ],
    ),
  );
  return ok ?? false;
}

/// Dialog shell: rounded, a heading, a muted message and a row of actions.
class OrbiDialog extends StatelessWidget {
  const OrbiDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
  });

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(
      child: content ?? (message == null ? null : Text(message!)),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(
      AppSpace.s4,
      0,
      AppSpace.s4,
      AppSpace.s4,
    ),
    actionsAlignment: MainAxisAlignment.end,
    actionsOverflowAlignment: OverflowBarAlignment.end,
    actionsOverflowButtonSpacing: AppSpace.s2,
    actions: actions,
  );
}

class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.error,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.touch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: context.text.labelLarge!.copyWith(color: c.onError),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
