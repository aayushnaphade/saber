/// Design system spacing constants
/// All spacing values follow an 8px base unit with a consistent scale
class AppSpacing {
  AppSpacing._(); // Private constructor to prevent instantiation

  /// Extra extra small spacing - 2px
  /// Use for: minimal gaps between tightly coupled elements
  static const xxs = 2.0;

  /// Micro spacing - 4px
  /// Use for: very tight groupings, icon padding
  static const xs = 4.0;

  /// Small spacing - 8px
  /// Use for: tight element grouping, list item internal padding
  static const sm = 8.0;

  /// Medium spacing - 16px (base unit)
  /// Use for: standard card padding, general element spacing
  static const md = 16.0;

  /// Large spacing - 24px
  /// Use for: section spacing, card margins, generous padding
  static const lg = 24.0;

  /// Extra large spacing - 32px
  /// Use for: page-level spacing, major section gaps
  static const xl = 32.0;

  /// Extra extra large spacing - 48px
  /// Use for: top-level page margins, hero section spacing
  static const xxl = 48.0;

  // Specialized spacing for specific use cases

  /// Standard card internal padding
  static const double cardPadding = md;

  /// Spacing between major sections
  static const double sectionGap = lg;

  /// Standard page margin
  static const double pageMargin = lg;

  /// List item vertical spacing
  static const double listItemGap = sm;

  /// Icon container padding
  static const double iconPadding = sm;

  /// Form field spacing
  static const double formFieldGap = md;

  /// Minimum touch target size (48x48 as per Material Design)
  static const minTouchTarget = 48.0;
}
