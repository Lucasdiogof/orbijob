import 'package:flutter/material.dart';

import '../design/design.dart';
import 'focus_ring.dart';

enum AppButtonVariant { primary, secondary, tertiary }

/// Primary / secondary / tertiary button. Minimum 48 dp tall, wraps long labels instead of truncating.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = variant == AppButtonVariant.primary ? c.onPrimary : c.primary;
    final Widget lead = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : (icon != null
              ? Icon(icon, size: AppSize.iconSm)
              : const SizedBox.shrink());
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading || icon != null) ...[
          lead,
          const SizedBox(width: AppSpace.s2),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    final VoidCallback? cb = loading ? null : onPressed;
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: cb, child: content),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: cb,
        child: content,
      ),
      AppButtonVariant.tertiary => TextButton(onPressed: cb, child: content),
    };
    final ringed = FocusRing(child: button);
    return expand ? SizedBox(width: double.infinity, child: ringed) : ringed;
  }
}
