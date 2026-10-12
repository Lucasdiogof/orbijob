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
      // Display / Heading large / Heading medium / Heading small
      displayLarge: _style(d, 28, 34, FontWeight.w700, spacing: -0.3),
      displayMedium: _style(d, 24, 30, FontWeight.w700, spacing: -0.2),
      displaySmall: _style(d, 22, 28, FontWeight.w700, spacing: -0.2),
      headlineLarge: _style(d, 22, 28, FontWeight.w700, spacing: -0.2),
      headlineMedium: _style(d, 18, 24, FontWeight.w600, spacing: -0.1),
      headlineSmall: _style(d, 16, 22, FontWeight.w600),
      titleLarge: _style(d, 18, 24, FontWeight.w600, spacing: -0.1),
      titleMedium: _style(d, 16, 22, FontWeight.w600),
      titleSmall: _style(d, 15, 20, FontWeight.w600),
      // Body / Body emphasis (labelLarge) / Label / Caption / Metadata
      bodyLarge: _style(t, 16, 24, FontWeight.w400),
      bodyMedium: _style(t, 15, 22, FontWeight.w400),
      bodySmall: _style(t, 13, 18, FontWeight.w400),
      labelLarge: _style(t, 15, 22, FontWeight.w600),
      labelMedium: _style(t, 13, 16, FontWeight.w600),
      labelSmall: _style(t, 12, 16, FontWeight.w500),
    ).apply(bodyColor: c.ink, displayColor: c.ink);
  }

  /// Metadata (dates, sources, counts): 12/16, medium weight, in the muted colour.
  static TextStyle metadata(Color color) =>
      _style(AppFonts.text, 12, 16, FontWeight.w500).copyWith(color: color);

  /// Caption: 12/16 regular.
  static TextStyle caption(Color color) =>
      _style(AppFonts.text, 12, 16, FontWeight.w400).copyWith(color: color);

  /// JetBrains Mono, reserved for technical identifiers (ISO currency and country codes, source ids).
  static TextStyle technical(Color color) => _style(
    AppFonts.mono,
    12,
    16,
    FontWeight.w500,
    spacing: 0.2,
  ).copyWith(color: color);
}
