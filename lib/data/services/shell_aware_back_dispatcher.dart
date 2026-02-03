import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/services/back_navigation_service.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/home/home.dart';

/// A custom BackButtonDispatcher that intercepts system back gestures
/// and routes them through our navigation logic instead of letting
/// GoRouter handle them directly.
///
/// This is necessary because GoRouter's default BackButtonDispatcher
/// will pop the shell route entirely when there's nothing in the
/// nested navigator stack, which exits the app unexpectedly.
class ShellAwareBackButtonDispatcher extends RootBackButtonDispatcher {
  ShellAwareBackButtonDispatcher({
    required this.router,
  });

  final GoRouter router;
  
  /// Global key for accessing the scaffold messenger
  static final scaffoldMessengerKey = 
      GlobalKey<ScaffoldMessengerState>();

  @override
  Future<bool> didPopRoute() async {
    // Get the current location from the router
    final currentLocation = router.routerDelegate.currentConfiguration.uri.path;
    
    // Determine the current subpage based on the path
    final subpage = _getSubpageFromPath(currentLocation);
    
    // Check if we're within the shell (home) routes
    if (_isInShellRoute(currentLocation)) {
      // Get the navigation result from our service
      final navResult = BackNavigationService.getBackNavigationResult(
        currentPath: currentLocation,
        currentSubpage: subpage,
      );

      switch (navResult.action) {
        case BackNavigationAction.navigateTo:
          if (navResult.targetRoute != null) {
            router.go(navResult.targetRoute!);
          }
          return true; // We handled the back event

        case BackNavigationAction.showExitConfirmation:
          // Show the exit confirmation snackbar
          _showExitConfirmationSnackbar();
          return true; // We handled the back event

        case BackNavigationAction.exitApp:
          // Exit the app
          SystemNavigator.pop();
          return true;
      }
    }

    // For routes outside the shell (login, editor, etc.), let GoRouter handle it
    return super.didPopRoute();
  }

  /// Shows the "swipe again to exit" snackbar
  void _showExitConfirmationSnackbar() {
    // Try to get the scaffold messenger from the navigator context
    final navigatorContext = router.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext != null) {
      ScaffoldMessenger.of(navigatorContext).clearSnackBars();
      ScaffoldMessenger.of(navigatorContext).showSnackBar(
        SnackBar(
          content: Text(t.common.backAgainToExit),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Determines the subpage from the current path
  String _getSubpageFromPath(String path) {
    if (path.contains('/patients')) {
      return HomePage.browseSubpage;
    }
    
    // Match /home/:subpage pattern
    final homePattern = RegExp(r'^/home/([^/]+)');
    final match = homePattern.firstMatch(path);
    if (match != null) {
      final subpage = match.group(1);
      if (subpage != null && HomePage.subpages.contains(subpage)) {
        return subpage;
      }
    }
    
    return HomePage.dashboardSubpage;
  }

  /// Checks if the current path is within the shell route
  bool _isInShellRoute(String path) {
    return path.startsWith(RoutePaths.prefixOfHome);
  }
}
