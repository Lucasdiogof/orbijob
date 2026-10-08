import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../typography/app_typography.dart';

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  TextStyle get technicalStyle => AppTypography.technical(colors.muted);
}
