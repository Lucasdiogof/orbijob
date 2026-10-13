import 'package:flutter/material.dart';

import '../design/design.dart';
import '../widgets/focus_ring.dart';

/// A filled (not outlined) selectable chip, 36 dp tall inside a 44 dp touch target. Selection is carried by the brand fill,
/// a check mark and the semantic `selected` flag, never by colour alone.
class OrbiFilterChip extends StatelessWidget {
  const OrbiFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.trailing,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  /// A small trailing hint such as a count or a dropdown arrow.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.chipSelectedFg : c.ink;
    final enabled = onSelected != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? () => onSelected!(!selected) : null,
      child: FocusRing(
        radius: AppRadius.pill,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Material(
              color: selected ? c.chipSelectedBg : c.chipBg,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: enabled ? () => onSelected!(!selected) : null,
                hoverColor: c.hoverLayer,
                highlightColor: c.pressedLayer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        Icon(Icons.check, size: 16, color: fg)
                      else if (icon != null)
                        Icon(icon, size: 16, color: fg),
                      if (selected || icon != null)
                        const SizedBox(width: AppSpace.s2 - 2),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelMedium!.copyWith(color: fg),
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: AppSpace.s1),
                        trailing!,
                      ],
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
}

/// A horizontally scrolling row of quick filters with a soft fade on the trailing edge, so cut-off chips read as "more" and not as a bug.
class OrbiChipRow extends StatelessWidget {
  const OrbiChipRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpace.s4),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: padding,
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s2),
            itemBuilder: (_, i) => Center(child: children[i]),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: AppSpace.s6,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bg.withValues(alpha: 0), bg],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum OrbiBadgeKind { neutral, info, success, warning, error }

/// Small, quiet, non-interactive label: tinted fill, no outline. Meaning is in the text (and the icon); colour only reinforces it.
class OrbiStatusBadge extends StatelessWidget {
  const OrbiStatusBadge({
    super.key,
    required this.label,
    this.kind = OrbiBadgeKind.neutral,
    this.icon,
  });

  final String label;
  final OrbiBadgeKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (kind) {
      OrbiBadgeKind.neutral => (c.container, c.muted),
      OrbiBadgeKind.info => (c.primaryContainer, c.onPrimaryContainer),
      OrbiBadgeKind.success => (c.successContainer, c.onSuccessContainer),
      OrbiBadgeKind.warning => (c.warningContainer, c.onWarningContainer),
      OrbiBadgeKind.error => (c.errorContainer, c.onErrorContainer),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall!.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
