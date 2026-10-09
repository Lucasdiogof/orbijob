import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

abstract final class AppFonts {
  static const String display = 'SpaceGrotesk';
  static const String text = 'Inter';
  static const String mono = 'JetBrainsMono';

  /// Only Latin glyphs are bundled (pt, en, es). Other scripts use the platform fonts listed here;
  /// on the web the engine downloads a matching fallback on demand.
  static const List<String> fallback = <String>[
    'Inter',
    'Noto Sans',
    'Noto Sans Arabic',
    'Noto Sans Devanagari',
    'Noto Sans JP',
    'Noto Sans KR',
    'Noto Sans SC',
    'Noto Sans TC',
  ];
}

abstract final class AppTypography {
  static TextStyle _style(
    String family,
    double size,
    double line,
    FontWeight weight, {
    double spacing = 0,
  }) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: size,
    height: line / size,
    fontWeight: weight,
    letterSpacing: spacing,
  );

  /// Space Grotesk for titles and brand moments, Inter for reading and controls.
  static TextTheme textTheme(AppColors c) {
    const d = AppFonts.display;
    const t = AppFonts.text;
    return TextTheme(
      displayLarge: _style(d, 32, 40, FontWeight.w700, spacing: -0.2),
      displayMedium: _style(d, 28, 36, FontWeight.w700, spacing: -0.2),
      displaySmall: _style(d, 24, 32, FontWeight.w700, spacing: -0.1),
      headlineLarge: _style(d, 28, 36, FontWeight.w700, spacing: -0.2),
      headlineMedium: _style(d, 24, 32, FontWeight.w700, spacing: -0.1),
      headlineSmall: _style(d, 20, 28, FontWeight.w600),
      titleLarge: _style(d, 20, 28, FontWeight.w600),
      titleMedium: _style(d, 17, 24, FontWeight.w600),
      titleSmall: _style(d, 15, 22, FontWeight.w600),
      bodyLarge: _style(t, 16, 24, FontWeight.w400),
      bodyMedium: _style(t, 15, 22, FontWeight.w400),
      bodySmall: _style(t, 13, 18, FontWeight.w400),
      labelLarge: _style(t, 15, 20, FontWeight.w600),
      labelMedium: _style(t, 13, 16, FontWeight.w600),
      labelSmall: _style(t, 12, 16, FontWeight.w600, spacing: 0.2),
    ).apply(bodyColor: c.ink, displayColor: c.ink);
  }

  /// JetBrains Mono, reserved for technical identifiers (ISO currency and country codes, source ids).
  static TextStyle technical(Color color) => _style(
    AppFonts.mono,
    12,
    16,
    FontWeight.w500,
    spacing: 0.2,
  ).copyWith(color: color);
}
