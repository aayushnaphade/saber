import 'package:flutter/material.dart';

/// Design system border radius constants
/// Consistent corner rounding for visual harmony
class AppRadius {
  AppRadius._(); // Private constructor to prevent instantiation

  /// Extra small radius - 4px
  /// Use for: very small elements, minimal rounding
  static const double xs = 4.0;

  /// Small radius - 8px
  /// Use for: chips, small badges
  static const double sm = 8.0;

  /// Medium radius - 12px
  /// Use for: standard buttons, input fields
  static const double md = 12.0;

  /// Large radius - 16px
  /// Use for: standard cards, containers
  static const double lg = 16.0;

  /// Extra large radius - 20px
  /// Use for: prominent cards, feature containers
  static const double xl = 20.0;

  /// Extra extra large radius - 28px
  /// Use for: hero cards, major feature areas
  static const double xxl = 28.0;

  /// Full radius (circular) - 9999px
  /// Use for: pills, badges, circular elements
  static const double full = 9999.0;

  /// Pill shape - 100px
  /// Use for: fully rounded pill buttons, status badges
  static const double pill = 100.0;

  // BorderRadius helpers for common cases

  static BorderRadius get xsRadius => BorderRadius.circular(xs);
  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
  static BorderRadius get xxlRadius => BorderRadius.circular(xxl);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}
