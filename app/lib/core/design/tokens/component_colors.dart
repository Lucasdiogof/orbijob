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
  Color get cardBorder => hairline;
  Color get cardBorderSelected => primary;

  Color get chipBg => container;
  Color get chipBorder => container; // chips are filled, not outlined
  Color get chipSelectedBg => primaryContainer;
  Color get chipSelectedFg => onPrimaryContainer;
  Color get chipSelectedBorder => primaryContainer;

  Color get navBg => surface;
  Color get navSelected => onPrimaryContainer;
  Color get navUnselected => muted;
  Color get navIndicator =>
      primaryContainer; // the capsule behind the selected icon

  Color get loading => primary;
  Color get clear => const Color(0x00000000);
  Color get selectedBg => primaryContainer;

  Color get hoverLayer => primary.withValues(alpha: 0.08);
  Color get pressedLayer => primary.withValues(alpha: 0.12);
  Color get focusLayer => primary.withValues(alpha: 0.12);
}
