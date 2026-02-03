import 'package:flutter/material.dart';

/// Design system animation constants
/// Consistent timing and easing for all animations
class AppAnimations {
  AppAnimations._(); // Private constructor to prevent instantiation

  // Duration constants

  /// Very fast animation - 100ms
  /// Use for: micro-interactions, button feedback
  static const Duration veryFast = Duration(milliseconds: 100);

  /// Fast animation - 200ms
  /// Use for: quick transitions, hover effects
  static const Duration fast = Duration(milliseconds: 200);

  /// Normal animation - 300ms
  /// Use for: standard transitions, card animations
  static const Duration normal = Duration(milliseconds: 300);

  /// Slow animation - 500ms
  /// Use for: complex transitions, page changes
  static const Duration slow = Duration(milliseconds: 500);

  /// Very slow animation - 700ms
  /// Use for: dramatic effects, major state changes
  static const Duration verySlow = Duration(milliseconds: 700);

  // Curve constants

  /// Standard easing - easeInOut
  /// Use for: most animations
  static const Curve standard = Curves.easeInOut;

  /// Emphasized easing - fastOutSlowIn
  /// Use for: entering elements
  static const Curve emphasized = Curves.fastOutSlowIn;

  /// Decelerated easing - easeOut
  /// Use for: entering from offscreen
  static const Curve decelerated = Curves.easeOut;

  /// Accelerated easing - easeIn
  /// Use for: exiting animations
  static const Curve accelerated = Curves.easeIn;

  /// Bounce easing
  /// Use for: playful interactions, success feedback
  static const Curve bounce = Curves.bounceOut;

  /// Elastic easing
  /// Use for: spring-like movements
  static const Curve elastic = Curves.elasticOut;

  // Specialized animation configs

  /// Button press animation
  static const Duration buttonPress = veryFast;
  static const Curve buttonPressCurve = standard;
  static const double buttonPressScale = 0.95;

  /// Card appearance animation
  static const Duration cardAppear = normal;
  static const Curve cardAppearCurve = emphasized;

  /// Page transition animation
  static const Duration pageTransition = normal;
  static const Curve pageTransitionCurve = standard;

  /// Data update animation
  static const Duration dataUpdate = fast;
  static const Curve dataUpdateCurve = standard;

  /// Status change animation
  static const Duration statusChange = normal;
  static const Curve statusChangeCurve = standard;

  /// Loading animation
  static const Duration loading = normal;
  static const Curve loadingCurve = standard;

  /// Success feedback animation
  static const Duration success = slow;
  static const Curve successCurve = bounce;

  /// Error shake animation
  static const Duration errorShake = fast;
  static const Curve errorShakeCurve = elastic;
}
