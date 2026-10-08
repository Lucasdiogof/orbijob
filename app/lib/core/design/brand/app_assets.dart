import 'package:flutter/material.dart';

/// Single place that knows where brand assets live (copies of docs/design/identity/c-minimal, kept in sync by a test).
abstract final class AppAssets {
  static const String _dir = 'assets/brand';

  static String logoHorizontal(Brightness b) =>
      '$_dir/logo-horizontal-${b == Brightness.dark ? 'dark' : 'light'}.svg';
  static String symbol(Brightness b) =>
      '$_dir/symbol-${b == Brightness.dark ? 'dark' : 'light'}.svg';

  static const String logoMonoBlack = '$_dir/logo-horizontal-mono-black.svg';
  static const String logoMonoWhite = '$_dir/logo-horizontal-mono-white.svg';
  static const String symbolMonoBlack = '$_dir/symbol-mono-black.svg';
  static const String symbolMonoWhite = '$_dir/symbol-mono-white.svg';

  static const List<String> all = <String>[
    '$_dir/logo-horizontal-light.svg',
    '$_dir/logo-horizontal-dark.svg',
    logoMonoBlack,
    logoMonoWhite,
    '$_dir/symbol-light.svg',
    '$_dir/symbol-dark.svg',
    symbolMonoBlack,
    symbolMonoWhite,
  ];

  /// OFL licence texts bundled with the fonts; registered with Flutter's LicenseRegistry at startup.
  static const List<(String, String)> fontLicenses = <(String, String)>[
    ('Space Grotesk', 'assets/fonts/OFL-SpaceGrotesk.txt'),
    ('Inter', 'assets/fonts/OFL-Inter.txt'),
    ('JetBrains Mono', 'assets/fonts/OFL-JetBrainsMono.txt'),
  ];
}
