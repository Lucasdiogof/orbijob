import 'package:flutter/material.dart';

import '../design/design.dart';
import '../widgets/focus_ring.dart';
import 'orbi_loader.dart';

/// Primary action: filled with the brand colour. At most one per screen region.
class OrbiPrimaryButton extends StatelessWidget {
  const OrbiPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) => _OrbiButton(
    kind: _Kind.primary,
    label: label,
    onPressed: onPressed,
    icon: icon,
    loading: loading,
    expand: expand,
  );
}

/// Secondary action: a quiet tonal button (no heavy outline).
class OrbiSecondaryButton extends StatelessWidget {
  const OrbiSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) => _OrbiButton(
    kind: _Kind.secondary,
    label: label,
    onPressed: onPressed,
    icon: icon,
    loading: loading,
    expand: expand,
  );
}

/// Tertiary action: text only.
class OrbiTextButton extends StatelessWidget {
  const OrbiTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) => _OrbiButton(
    kind: _Kind.text,
    label: label,
    onPressed: onPressed,
    icon: icon,
    loading: false,
    expand: expand,
  );
}

enum _Kind { primary, secondary, text }

class _OrbiButton extends StatelessWidget {
  const _OrbiButton({
    required this.kind,
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.loading,
    required this.expand,
  });

  final _Kind kind;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !loading;
    final fg = switch (kind) {
      _Kind.primary => enabled ? c.onPrimary : c.disabledFg,
      _Kind.secondary => enabled ? c.onPrimaryContainer : c.disabledFg,
      _Kind.text => enabled ? c.primary : c.disabledFg,
    };
    final bg = switch (kind) {
      _Kind.primary => enabled ? c.primary : c.disabledBg,
      _Kind.secondary => enabled ? c.primaryContainer : c.disabledBg,
      _Kind.text => c.clear,
    };
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          OrbiLoadingIndicator(size: 18, color: fg),
          const SizedBox(width: AppSpace.s2),
        ] else if (icon != null) ...[
          Icon(icon, size: AppSize.iconSm, color: fg),
          const SizedBox(width: AppSpace.s2),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.text.labelLarge!.copyWith(color: fg),
          ),
        ),
      ],
    );
    final button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: FocusRing(
        radius: AppRadius.md,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            hoverColor: (kind == _Kind.primary ? c.onPrimary : c.primary)
                .withValues(alpha: AppStateLayer.hover),
            highlightColor: (kind == _Kind.primary ? c.onPrimary : c.primary)
                .withValues(alpha: AppStateLayer.pressed),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSize.touch,
                minWidth: AppSize.touch,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: kind == _Kind.text ? AppSpace.s3 : AppSpace.s5,
                  vertical: AppSpace.s2,
                ),
                child: Center(widthFactor: 1, heightFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
