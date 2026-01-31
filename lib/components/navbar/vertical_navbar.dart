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
      .linux => Colors.transparent,
      _ => theme.colorScheme.surfaceContainer,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: theme.platform == .linux
            ? BoxBorder.fromSTEB(end: BorderSide(color: theme.dividerColor))
            : null,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const SizedBox(height: kToolbarHeight),
          Padding(
            padding: const .symmetric(vertical: 10, horizontal: 12),
            child: TextButton(
              onPressed: () {
                setState(() {
                  expanded = !expanded;
                });
              },
              child: AdaptiveIcon(
                icon: expanded ? Icons.chevron_left : Icons.chevron_right,
                cupertinoIcon: expanded
                    ? CupertinoIcons.chevron_left
                    : CupertinoIcons.chevron_right,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: IntrinsicHeight(
                child: NavigationRail(
                  key: ValueKey(expanded),
                  destinations: widget.destinations,
                  selectedIndex: widget.selectedIndex,
                  backgroundColor: backgroundColor,
                  extended: expanded,
                  minExtendedWidth: 220,
                  onDestinationSelected: widget.onDestinationSelected,
                  useIndicator: true,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: expanded
                ? FilledButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Sign Out'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.errorContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onErrorContainer,
                    ),
                  )
                : IconButton(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout, size: 20),
                    tooltip: 'Sign Out',
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
