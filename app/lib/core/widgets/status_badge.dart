import 'package:flutter/material.dart';

import '../design/design.dart';

enum BadgeKind { neutral, info, success, warning, error }

/// Small non-interactive label. Meaning is carried by text + icon, colour only reinforces it.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.kind = BadgeKind.neutral,
    this.icon,
  });

  final String label;
  final BadgeKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (kind) {
      BadgeKind.neutral => (c.container, c.ink),
      BadgeKind.info => (c.primaryContainer, c.onPrimaryContainer),
      BadgeKind.success => (c.successContainer, c.onSuccessContainer),
      BadgeKind.warning => (c.warningContainer, c.onWarningContainer),
      BadgeKind.error => (c.errorContainer, c.onErrorContainer),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: AppSpace.s1),
            ],
            Flexible(
              child: Text(
                label,
                style: context.text.labelSmall!.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
