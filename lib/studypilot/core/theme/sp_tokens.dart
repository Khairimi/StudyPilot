import 'package:flutter/material.dart';

/// Spacing scale (4-pt grid), matching the prototype's Tailwind spacing.
class SpSpacing {
  SpSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16; // default screen / card padding on mobile
  static const double xl = 24;
  static const double xxl = 32;

  /// Minimum touch target (prototype: 44px+ hitboxes).
  static const double minTouch = 44;
}

/// Layout breakpoints (logical pixels).
class SpBreakpoints {
  SpBreakpoints._();

  /// Navigation rail replaces the bottom bar (Material 3 "medium").
  static const double navigationRail = 840;
}

/// Corner radii: rounded-lg / rounded-xl / rounded-2xl / rounded-full.
class SpRadius {
  SpRadius._();
  static const double sm = 8;
  static const double md = 12; // default for inputs, buttons, chips
  static const double lg = 16; // cards
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius control = BorderRadius.all(Radius.circular(md));
}
