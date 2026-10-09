import 'package:flutter/material.dart';

import '../design/design.dart';
import 'focus_ring.dart';

class AppDestination {
  const AppDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// One-line label that shrinks to fit its slot instead of breaking inside a word.
class _FitLabel extends StatelessWidget {
  const _FitLabel(this.text, {required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: style,
    ),
  );
}

MediaQueryData _clamped(BuildContext context) => MediaQuery.of(context)
    .copyWith(
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
    );

/// Bottom navigation for compact windows. The selected item has a 2 px top line, a filled icon and bold,
/// accent-coloured label; the full label stays available to screen readers at any text scale.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.semanticLabel,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Material(
        color: c.navBg,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.divider)),
          ),
          child: SafeArea(
            top: false,
            child: MediaQuery(
              data: _clamped(context),
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _BarItem(
                        d: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.d,
    required this.selected,
    required this.onTap,
  });
  final AppDestination d;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.navSelected : c.navUnselected;
    return Semantics(
      button: true,
      selected: selected,
      label: d.label,
      excludeSemantics: true,
      onTap: onTap,
      child: FocusRing(
        radius: 0,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 2, color: selected ? c.navIndicator : null),
                const SizedBox(height: AppSpace.s2),
                Icon(
                  selected ? d.selectedIcon : d.icon,
                  color: color,
                  size: AppSize.icon,
                ),
                const SizedBox(height: AppSpace.s1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
                  child: _FitLabel(
                    d.label,
                    style: context.text.labelSmall!.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Side navigation for medium/expanded windows. [extended] shows icon + label on one row;
/// [showLabels] false (short landscape windows) keeps icons only, with tooltips and semantic labels.
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.leading,
    this.extended = false,
    this.showLabels = true,
    this.semanticLabel,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? leading;
  final bool extended;
  final bool showLabels;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final width = extended ? AppSize.railExtendedWidth : AppSize.railWidth;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Material(
        color: c.navBg,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: c.divider)),
          ),
          child: SizedBox(
            width: width,
            child: SafeArea(
              right: false,
              child: MediaQuery(
                data: _clamped(context),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (leading != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s4),
                          child: Center(child: leading),
                        ),
                      for (var i = 0; i < destinations.length; i++)
                        _RailItem(
                          d: destinations[i],
                          selected: i == selectedIndex,
                          extended: extended,
                          showLabel: showLabels,
                          onTap: () => onSelected(i),
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

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.d,
    required this.selected,
    required this.extended,
    required this.showLabel,
    required this.onTap,
  });
  final AppDestination d;
  final bool selected;
  final bool extended;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.navSelected : c.navUnselected;
    final icon = Icon(
      selected ? d.selectedIcon : d.icon,
      color: color,
      size: AppSize.icon,
    );
    final labelStyle = context.text.labelMedium!.copyWith(
      color: color,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    final label = extended
        ? Text(d.label, style: labelStyle)
        : _FitLabel(d.label, style: labelStyle);
    final child = extended
        ? Row(
            children: [
              icon,
              const SizedBox(width: AppSpace.s3),
              Expanded(child: label),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              if (showLabel) ...[const SizedBox(height: AppSpace.s1), label],
            ],
          );
    return Semantics(
      button: true,
      selected: selected,
      label: d.label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: d.label,
        child: FocusRing(
          radius: 0,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: EdgeInsets.symmetric(
                horizontal: extended ? AppSpace.s4 : AppSpace.s1,
                vertical: AppSpace.s2,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: selected ? c.navIndicator : c.navBg,
                    width: 3,
                  ),
                ),
              ),
              alignment: extended ? Alignment.centerLeft : Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
