import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/components/theming/premium_confirmation_dialog.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/supabase/supabase_auth_service.dart';

class VerticalNavbar extends StatefulWidget {
  const VerticalNavbar({
    super.key,
    required this.destinations,
    this.selectedIndex,
    this.onDestinationSelected,
  });

  final List<NavigationRailDestination> destinations;
  final int? selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  @override
  State<VerticalNavbar> createState() => _VerticalNavbarState();
}

class _VerticalNavbarState extends State<VerticalNavbar> {
  var expanded = false;

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => const PremiumConfirmationDialog(
        title: 'Sign Out',
        content: 'Are you sure you want to sign out?',
        confirmLabel: 'Sign Out',
        isDestructive: true,
        icon: Icons.logout_rounded,
      ),
    );

    if ((confirm ?? false) && mounted) {
      try {
        await SupabaseAuthService.signOut();
        if (mounted) {
          context.go(RoutePaths.login);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sign out: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add a unique key based on expanded state to force partial redraws if needed,
    // though proper widget refactoring is key.
    // Here we use a stable structure.

    final theme = Theme.of(context);
    final backgroundColor = switch (theme.platform) {
      TargetPlatform.linux => Colors.transparent,
      _ => theme.colorScheme.surfaceContainer,
    };

    const animationDuration = Duration(milliseconds: 300);
    const animationCurve = Curves.easeInOut;

    return Material(
      color: backgroundColor,
      child: AnimatedContainer(
        duration: animationDuration,
        curve: animationCurve,
        width: expanded ? 240 : 72,
        decoration: BoxDecoration(
          gradient: theme.brightness == Brightness.light
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor,
                    Color.alphaBlend(
                      theme.colorScheme.primary.withAlpha(10),
                      backgroundColor,
                    ),
                  ],
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                theme.brightness == Brightness.light ? 10 : 30,
              ),
              blurRadius: 10,
              offset: const Offset(2, 0),
            ),
          ],
          border: theme.platform == TargetPlatform.linux
              ? Border(right: BorderSide(color: theme.dividerColor))
              : Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(80),
                  ),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: _buildAppLogo(theme, animationDuration, animationCurve),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < widget.destinations.length; i++)
                      _buildType3RailItem(
                        context,
                        destination: widget.destinations[i],
                        isSelected: i == widget.selectedIndex,
                        onTap: () => widget.onDestinationSelected?.call(i),
                        duration: animationDuration,
                        curve: animationCurve,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Align(
                alignment: expanded ? Alignment.centerRight : Alignment.center,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        expanded = !expanded;
                      });
                    },
                    child: AnimatedContainer(
                      duration: animationDuration,
                      curve: animationCurve,
                      height: 48,
                      width: expanded ? 200 : 48,
                      alignment: expanded
                          ? Alignment.centerRight
                          : Alignment.center,
                      padding: expanded
                          ? const EdgeInsets.only(right: 12)
                          : EdgeInsets.zero,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(
                            0.5,
                          ),
                          width: 1,
                        ),
                        color: expanded
                            ? theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.3)
                            : Colors.transparent,
                      ),
                      child: AnimatedRotation(
                        duration: animationDuration,
                        curve: animationCurve,
                        turns: expanded ? 0.5 : 0,
                        child: AdaptiveIcon(
                          icon: Icons.chevron_right,
                          cupertinoIcon: CupertinoIcons.chevron_right,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: _buildSignOutButton(
                theme,
                animationDuration,
                animationCurve,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAppLogo(ThemeData theme, Duration duration, Curve curve) {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(top: 24), // Align with dashboard content
      child: AnimatedPadding(
        duration: duration,
        curve: curve,
        padding: EdgeInsets.symmetric(horizontal: expanded ? 24 : 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center when collapsed
          children: [
            Image.asset(
              'assets/android/playstore-icon.png',
              width: 44, // Increased size
              height: 44,
            ),
            AnimatedContainer(
              duration: duration,
              curve: curve,
              width: expanded ? 16 : 0, // Increased spacing
            ),
            Expanded(
              child: AnimatedOpacity(
                duration: duration,
                curve: curve,
                opacity: expanded ? 1.0 : 0.0,
                child: Text(
                  'SynapseAI',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    // Larger texture
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton(ThemeData theme, Duration duration, Curve curve) {
    return Tooltip(
      message: expanded ? '' : 'Sign Out',
      child: AnimatedPadding(
        duration: duration,
        curve: curve,
        padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 8),
        child: Material(
          color: expanded ? theme.colorScheme.error : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 48,
              child: AnimatedPadding(
                duration: duration,
                curve: curve,
                padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: 240,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRect(
                        child: Align(
                          widthFactor: 1.0,
                          child: Icon(
                            Icons.logout_rounded,
                            size: expanded ? 24 : 32,
                            color: expanded
                                ? theme.colorScheme.onError
                                : theme.colorScheme.error,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: duration,
                        curve: curve,
                        width: expanded ? 12 : 0,
                      ),
                      AnimatedOpacity(
                        duration: duration,
                        curve: curve,
                        opacity: expanded ? 1.0 : 0.0,
                        child: Text(
                          'Sign Out',
                          softWrap: false,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onError,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildType3RailItem(
    BuildContext context, {
    required NavigationRailDestination destination,
    required bool isSelected,
    required VoidCallback onTap,
    required Duration duration,
    required Curve curve,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final iconWidget = isSelected
        ? (destination.selectedIcon ?? destination.icon)
        : destination.icon;

    final baseStyle = isSelected
        ? theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          )
        : theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          );

    return Tooltip(
      message: expanded ? '' : (destination.label as Text).data ?? '',
      child: AnimatedPadding(
        duration: duration,
        curve: curve,
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 12 : 8,
          vertical: 4,
        ),
        child: Material(
          color: isSelected
              ? colorScheme.primary.withAlpha(40)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 58,
              child: AnimatedPadding(
                duration: duration,
                curve: curve,
                padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 8),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: 240,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconTheme(
                        data: IconThemeData(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                        child: iconWidget,
                      ),
                      AnimatedContainer(
                        duration: duration,
                        curve: curve,
                        width: expanded ? 12 : 0,
                      ),
                      AnimatedOpacity(
                        duration: duration,
                        curve: curve,
                        opacity: expanded ? 1.0 : 0.0,
                        child: DefaultTextStyle(
                          style: baseStyle ?? const TextStyle(),
                          maxLines: 1,
                          softWrap: false,
                          child: destination.label,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
