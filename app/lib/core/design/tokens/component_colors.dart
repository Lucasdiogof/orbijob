import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Component-level colour aliases. They map to base roles so that a single change in the
/// token source restyles every component; widgets never use raw colours.
extension AppComponentColors on AppColors {
  Color get inputFill => surface;
  Color get inputBorder => outline;
  Color get inputBorderFocused => focus;
  Color get inputPlaceholder => muted;

  Color get cardBg => surface;
  Color get cardBorder => divider;
  Color get cardBorderSelected => primary;

  Color get chipBg => surface;
  Color get chipBorder => outline;
  Color get chipSelectedBg => primaryContainer;
  Color get chipSelectedFg => onPrimaryContainer;
  Color get chipSelectedBorder => primary;

  Color get navBg => surface;
  Color get navSelected => primary;
  Color get navUnselected => muted;
  Color get navIndicator => primary;

  Color get loading => primary;
  Color get selectedBg => primaryContainer;

  Color get hoverLayer => primary.withValues(alpha: 0.08);
  Color get pressedLayer => primary.withValues(alpha: 0.12);
  Color get focusLayer => primary.withValues(alpha: 0.12);
}
