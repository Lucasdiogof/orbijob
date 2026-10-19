import 'package:flutter/material.dart';

import '../design/design.dart';
import '../widgets/focus_ring.dart';
import 'orbi_loader.dart';

class OrbiDestination {
  const OrbiDestination({
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

/// Bottom navigation: a quiet surface with a hairline on top; the selected destination sits on a brand capsule behind its filled icon.
/// The full label stays available to screen readers at any text scale, and the bar hides under an open keyboard.
class OrbiNavigationBar extends StatelessWidget {
  const OrbiNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.semanticLabel,
  });

  final List<OrbiDestination> destinations;
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
            border: Border(top: BorderSide(color: c.hairline)),
          ),
          child: SafeArea(
            top: false,
            child: MediaQuery(
              data: _clamped(context),
              child: SizedBox(
                height: AppSize.navBarHeight,
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
  final OrbiDestination d;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.navSelected : c.navUnselected;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: d.label,
      excludeSemantics: true,
      onTap: onTap,
      child: FocusRing(
        radius: AppRadius.md,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: animate ? AppMotion.base : Duration.zero,
                curve: AppMotion.curve,
                width: AppSize.navPillWidth,
                height: AppSize.navPillHeight,
                decoration: BoxDecoration(
                  color: selected ? c.navIndicator : c.clear,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(
                  selected ? d.selectedIcon : d.icon,
                  color: color,
                  size: AppSize.icon,
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
                child: _FitLabel(
                  d.label,
                  style: context.text.labelSmall!.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Side navigation for medium and expanded windows: the brand on top, destinations as rounded rows, the profile entry at the bottom.
/// [extended] shows icon + label on one row; otherwise a compact rail (icons with small labels, or icons only in short landscape windows).
class OrbiSideNav extends StatelessWidget {
  const OrbiSideNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.leading,
    this.trailing,
    this.extended = false,
    this.showLabels = true,
    this.semanticLabel,
  });

  final List<OrbiDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? leading;
  final Widget? trailing;
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
            border: Border(right: BorderSide(color: c.hairline)),
          ),
          child: SizedBox(
            width: width,
            child: SafeArea(
              right: false,
              child: MediaQuery(
                data: _clamped(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (leading != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          extended ? AppSpace.s5 : AppSpace.s2,
                          AppSpace.s5,
                          AppSpace.s2,
                          AppSpace.s4,
                        ),
                        child: Align(
                          alignment: extended
                              ? Alignment.centerLeft
                              : Alignment.center,
                          child: leading,
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s2,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < destinations.length; i++)
                              _SideItem(
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
                    if (trailing != null)
                      Padding(
                        padding: const EdgeInsets.all(AppSpace.s2),
                        child: trailing,
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
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.d,
    required this.selected,
    required this.extended,
    required this.showLabel,
    required this.onTap,
  });
  final OrbiDestination d;
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
    final child = extended
        ? Row(
            children: [
              icon,
              const SizedBox(width: AppSpace.s3),
              Expanded(child: Text(d.label, style: labelStyle, maxLines: 1)),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              if (showLabel) ...[
                const SizedBox(height: 2),
                _FitLabel(d.label, style: labelStyle),
              ],
            ],
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s1),
      child: Semantics(
        button: true,
        selected: selected,
        label: d.label,
        excludeSemantics: true,
        onTap: onTap,
        child: Tooltip(
          message: d.label,
          child: FocusRing(
            radius: AppRadius.md,
            child: Material(
              color: selected ? c.navIndicator : c.clear,
              borderRadius: BorderRadius.circular(AppRadius.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                hoverColor: c.hoverLayer,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: EdgeInsets.symmetric(
                    horizontal: extended ? AppSpace.s4 : AppSpace.s1,
                    vertical: AppSpace.s2,
                  ),
                  alignment: extended ? Alignment.centerLeft : Alignment.center,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The profile entry of the top bar and of the side navigation: a circular tile with a person (or the first letter of the name).
class OrbiProfileButton extends StatelessWidget {
  const OrbiProfileButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.initial,
    this.extendedLabel,
  });

  final String tooltip;
  final VoidCallback onPressed;

  /// First letter of the signed-in name or e-mail; a person icon when null.
  final String? initial;

  /// When set, the button is drawn as a wide row (side navigation, extended).
  final String? extendedLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final avatar = DecoratedBox(
      decoration: BoxDecoration(
        color: c.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 36,
        child: Center(
          child: initial == null
              ? Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: c.onPrimaryContainer,
                )
              : Text(
                  initial!.toUpperCase(),
                  // a letter in a fixed 36 dp disc: it follows the text size only up to 1.2x so it stays inside the disc
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.2),
                  style: context.text.labelLarge!.copyWith(
                    color: c.onPrimaryContainer,
                  ),
                ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        child: FocusRing(
          radius: AppRadius.pill,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSize.touch,
                minWidth: AppSize.touch,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: extendedLabel == null
                    ? Center(widthFactor: 1, child: avatar)
                    : Row(
                        children: [
                          avatar,
                          const SizedBox(width: AppSpace.s3),
                          Expanded(
                            child: Text(
                              extendedLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelLarge,
                            ),
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
}

/// Top bar of the compact shell: the brand at the start, the profile at the end, no divider line.
class OrbiTopBar extends StatelessWidget implements PreferredSizeWidget {
  const OrbiTopBar({super.key, required this.brand, this.actions = const []});

  final Widget brand;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 56,
    titleSpacing: AppSpace.s4,
    title: brand,
    actions: [
      ...actions,
      const SizedBox(width: AppSpace.s2),
    ],
  );
}

/// Whole-page loader (initial load): the animated brand mark centred, with an optional line of text.
class OrbiPageLoading extends StatelessWidget {
  const OrbiPageLoading({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => OrbiLoadingView(label: label);
}
