import 'package:flutter/material.dart';

import '../design/design.dart';
import 'focus_ring.dart';

/// Selectable chip. Selection is shown by fill, border AND a check icon (not colour alone). 48 dp touch target.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.chipSelectedFg : c.ink;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onSelected != null,
      label: label,
      excludeSemantics: true,
      onTap: onSelected == null ? null : () => onSelected!(!selected),
      child: FocusRing(
        radius: AppRadius.md,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.touch),
          child: Center(
            widthFactor: 1,
            child: Material(
              color: selected ? c.chipSelectedBg : c.chipBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(
                  color: selected ? c.chipSelectedBorder : c.chipBorder,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: onSelected == null ? null : () => onSelected!(!selected),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        Icon(Icons.check, size: AppSize.iconSm, color: fg)
                      else if (icon != null)
                        Icon(icon, size: AppSize.iconSm, color: fg),
                      if (selected || icon != null)
                        const SizedBox(width: AppSpace.s2),
                      Flexible(
                        child: Text(
                          label,
                          style: context.text.labelMedium!.copyWith(color: fg),
                        ),
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
}
