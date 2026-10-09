import 'package:flutter/animation.dart';

/// Spacing scale (multiples of 4) from the identity tokens.
abstract final class AppSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 32;
  static const double s8 = 40;
  static const double s9 = 56;
}

abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
}

abstract final class AppSize {
  /// Minimum interactive target (dp).
  static const double touch = 48;
  static const double iconSm = 18;
  static const double icon = 24;
  static const double railWidth = 88;
  static const double railExtendedWidth = 232;
  static const double listPaneWidth = 420;
  static const double contentMaxWidth = 1120;
  static const double focusRingWidth = 2;
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve curve = Cubic(.2, 0, 0, 1);
}

/// Window-size classes: compact < 600, medium 600-1023, expanded >= 1024.
enum WindowClass {
  compact,
  medium,
  expanded;

  static WindowClass of(double width) {
    if (width < 600) return WindowClass.compact;
    if (width < 1024) return WindowClass.medium;
    return WindowClass.expanded;
  }
}

/// Opacity of the state layer drawn over `primary` for interaction states.
abstract final class AppStateLayer {
  static const double hover = 0.08;
  static const double focus = 0.12;
  static const double pressed = 0.12;
  static const double selected = 0.12;
}
