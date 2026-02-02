import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
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
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
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
    final theme = Theme.of(context);
    final backgroundColor = switch (theme.platform) {
      TargetPlatform.linux => Colors.transparent,
      _ => theme.colorScheme.surfaceContainer,
    };

    return Material(
      color: backgroundColor,
      child: DecoratedBox(
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
              color: Colors.black.withAlpha(theme.brightness == Brightness.light ? 10 : 30),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: kToolbarHeight),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    expanded = !expanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: expanded ? 0.5 : 0,
                    child: AdaptiveIcon(
                      icon: Icons.chevron_right,
                      cupertinoIcon: CupertinoIcons.chevron_right,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: NavigationRail(
                destinations: widget.destinations,
                selectedIndex: widget.selectedIndex,
                backgroundColor: Colors.transparent,
                groupAlignment: 0.0,
                extended: expanded,
                minExtendedWidth: 240,
                onDestinationSelected: widget.onDestinationSelected,
                useIndicator: true,
                indicatorColor: theme.colorScheme.primary.withAlpha(40),
                unselectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                selectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: FilledButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _handleLogout,
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 24,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: 'Sign Out',
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
