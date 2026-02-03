import 'package:flutter/material.dart';

/// Design system typography styles
/// Consistent text styling across the application
class AppTypography {
  AppTypography._(); // Private constructor to prevent instantiation

  // Display styles - for large, prominent text

  static TextStyle displayLarge(BuildContext context) {
    return Theme.of(context).textTheme.displayLarge!.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
    );
  }

  static TextStyle displayMedium(BuildContext context) {
    return Theme.of(context).textTheme.displayMedium!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.0,
      height: 1.2,
    );
  }

  // Headline styles - for section headings

  static TextStyle headlineLarge(BuildContext context) {
    return Theme.of(context).textTheme.headlineLarge!.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
      height: 1.2,
    );
  }

  static TextStyle headlineMedium(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.0,
      height: 1.3,
    );
  }

  static TextStyle headlineSmall(BuildContext context) {
    return Theme.of(context).textTheme.headlineSmall!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.0,
      height: 1.3,
    );
  }

  // Title styles - for card headers, list items

  static TextStyle titleLarge(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.0,
      height: 1.4,
    );
  }

  static TextStyle titleMedium(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      height: 1.4,
    );
  }

  static TextStyle titleSmall(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall!.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.4,
    );
  }

  // Body styles - for standard content

  static TextStyle bodyLarge(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0.0,
      height: 1.5,
    );
  }

  static TextStyle bodyMedium(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.5,
    );
  }

  static TextStyle bodySmall(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall!.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.4,
    );
  }

  // Label styles - for form labels, captions

  static TextStyle labelLarge(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.4,
    );
  }

  static TextStyle labelMedium(BuildContext context) {
    return Theme.of(context).textTheme.labelMedium!.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.3,
    );
  }

  static TextStyle labelSmall(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.2,
    );
  }

  // Specialized styles

  /// For emphasized body text
  static TextStyle bodyEmphasis(BuildContext context) {
    return bodyLarge(context).copyWith(fontWeight: FontWeight.w600);
  }

  /// For de-emphasized body text
  static TextStyle bodySubtle(BuildContext context) {
    return bodyMedium(
      context,
    ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
  }

  /// For data/numbers that should stand out
  static TextStyle dataValue(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.0,
      fontFeatures: [const FontFeature.tabularFigures()],
    );
  }

  /// For small caps labels (e.g., dates, section headers)
  static TextStyle overline(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      height: 1.2,
    );
  }

  /// For code or monospace text
  static TextStyle code(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontFamily: 'monospace',
      letterSpacing: 0.0,
    );
  }
}
