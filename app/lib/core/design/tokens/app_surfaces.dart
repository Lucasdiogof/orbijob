import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Depth tokens derived from the base roles (no new literal colours): the lit surface of a card, its soft shadow, the brand gradient of the primary
/// action and the ambient light of a hero area. Every tint moves toward the side that raises contrast, so text on these surfaces keeps its ratio.
extension AppSurfaces on AppColors {
  bool get isDark => bg.computeLuminance() < 0.5;

  /// A card is lit from the top: a barely lighter (dark) or barely cooler (light) top edge fading into the plain surface.
  Gradient get cardGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark
        ? [Color.lerp(surface, ink, 0.045)!, surface]
        : [surface, Color.lerp(surface, container, 0.55)!],
  );

  /// Dark mode stays flat (a shadow on near-black is mud); light mode gets a quiet two-layer lift.
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: ink.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ];

  /// The edge of a card while the pointer is over it: the hairline taking a hint of the brand colour.
  Color get cardBorderHover => Color.lerp(hairline, primary, 0.45)!;

  /// Brand gradient of the primary action; the second stop is pushed toward more contrast with [onPrimary].
  Gradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primary,
      Color.lerp(primary, isDark ? ink : onPrimaryContainer, 0.22)!,
    ],
  );

  /// The soft glow under the primary action (light mode only: on a dark surface it reads as a smudge).
  List<BoxShadow> get primaryGlow => isDark
      ? const []
      : [
          BoxShadow(
            color: primary.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];

  /// Ambient light of a hero area (static, painted once).
  RadialGradient get heroGlow => RadialGradient(
    center: const Alignment(0.9, -0.7),
    radius: 0.8,
    colors: [
      primary.withValues(alpha: isDark ? 0.20 : 0.13),
      primary.withValues(alpha: 0),
    ],
  );

  /// Thin orbit lines echoing the logo ring.
  Color get orbitLine => primary.withValues(alpha: isDark ? 0.14 : 0.10);
}
