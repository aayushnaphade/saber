import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/pages/home/home.dart';

/// A service that handles back navigation logic for the ShellRoute architecture.
/// 
/// This service determines the correct navigation behavior for back gestures
/// by analyzing the current route path and deciding whether to:
/// - Navigate to a parent route within the same "space" (e.g., Patient Profile -> Patient Browse)
/// - Navigate to the Dashboard from sidebar pages
/// - Show a "swipe again to exit" confirmation
/// - Exit the app
class BackNavigationService {
  BackNavigationService._();

  static DateTime? _lastBackPressTime;
  static const _exitConfirmationDuration = Duration(seconds: 2);

  /// Determines the result of a back navigation action.
  /// 
  /// Returns a [BackNavigationResult] indicating what action should be taken.
  static BackNavigationResult getBackNavigationResult({
    required String currentPath,
    required String currentSubpage,
  }) {
    // 1. Handle patient space navigation hierarchy
    if (_isInPatientSpace(currentPath)) {
      final parentRoute = _getPatientSpaceParentRoute(currentPath);
      if (parentRoute != null) {
        return BackNavigationResult.navigateTo(parentRoute);
      }
    }

    // 2. Handle session viewer -> patient profile navigation
    if (_isSessionViewer(currentPath)) {
      final patientRoute = _extractPatientProfileRoute(currentPath);
      if (patientRoute != null) {
        return BackNavigationResult.navigateTo(patientRoute);
      }
    }

    // 3. If not on Dashboard, navigate back to Dashboard
    if (currentSubpage != HomePage.dashboardSubpage) {
      return BackNavigationResult.navigateTo(HomeRoutes.getRoute(0));
    }

    // 4. On Dashboard - handle double-back-to-exit
    return _handleExitConfirmation();
  }

  /// Checks if the current path is within the patient space.
  static bool _isInPatientSpace(String path) {
    return path.contains('/patients');
  }

  /// Checks if the current path is the session viewer.
  static bool _isSessionViewer(String path) {
    return path.contains('/sessions/');
  }

  /// Gets the parent route within the patient space hierarchy.
  /// 
  /// Hierarchy:
  /// - /home/patients/:patientId/sessions/:sessionNumber -> /home/patients/:patientId
  /// - /home/patients/:patientId/:documentType -> /home/patients/:patientId
  /// - /home/patients/:patientId -> /home/patients (browse list)
  /// - /home/patients -> Dashboard (handled by main logic)
  static String? _getPatientSpaceParentRoute(String path) {
    // Pattern: /home/patients/:patientId/sessions/:sessionNumber
    final sessionViewerPattern = RegExp(
      r'^/home/patients/([^/]+)/sessions/\d+$',
    );
    if (sessionViewerPattern.hasMatch(path)) {
      final match = sessionViewerPattern.firstMatch(path);
      if (match != null) {
        final patientId = match.group(1);
        return '${RoutePaths.prefixOfHome}/patients/$patientId';
      }
    }

    // Pattern: /home/patients/:patientId/:documentType
    final patientDocumentsPattern = RegExp(
      r'^/home/patients/([^/]+)/([^/]+)$',
    );
    if (patientDocumentsPattern.hasMatch(path)) {
      final match = patientDocumentsPattern.firstMatch(path);
      if (match != null) {
        final patientId = match.group(1);
        final secondSegment = match.group(2);
        // Make sure the second segment isn't 'sessions' (handled above)
        if (secondSegment != 'sessions') {
          return '${RoutePaths.prefixOfHome}/patients/$patientId';
        }
      }
    }

    // Pattern: /home/patients/:patientId (patient profile)
    final patientProfilePattern = RegExp(
      r'^/home/patients/([^/]+)$',
    );
    if (patientProfilePattern.hasMatch(path)) {
      // Go back to patient browse list
      return RoutePaths.patients;
    }

    // Pattern: /home/patients (browse list) - return null to let main logic handle
    if (path == RoutePaths.patients || path == '${RoutePaths.patients}/') {
      return null;
    }

    return null;
  }

  /// Extracts the patient profile route from a session viewer path.
  static String? _extractPatientProfileRoute(String path) {
    final pattern = RegExp(r'^/home/patients/([^/]+)/sessions/');
    final match = pattern.firstMatch(path);
    if (match != null) {
      final patientId = match.group(1);
      return '${RoutePaths.prefixOfHome}/patients/$patientId';
    }
    return null;
  }

  /// Handles the double-back-to-exit pattern.
  static BackNavigationResult _handleExitConfirmation() {
    final now = DateTime.now();
    
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > _exitConfirmationDuration) {
      _lastBackPressTime = now;
      return BackNavigationResult.showExitConfirmation();
    }
    
    // User pressed back twice within the time window
    _lastBackPressTime = null;
    return BackNavigationResult.exitApp();
  }

  /// Resets the exit confirmation timer.
  /// Call this when the user navigates to a different page.
  static void resetExitTimer() {
    _lastBackPressTime = null;
  }

  /// Executes the back navigation action based on the result.
  static void executeBackNavigation(
    BuildContext context,
    BackNavigationResult result,
    String exitMessage,
  ) {
    // Safety check: verify context is still valid before performing operations
    if (!context.mounted) return;

    switch (result.action) {
      case BackNavigationAction.navigateTo:
        if (result.targetRoute != null && context.mounted) {
          context.go(result.targetRoute!);
        }
      case BackNavigationAction.showExitConfirmation:
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(exitMessage),
              duration: _exitConfirmationDuration,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      case BackNavigationAction.exitApp:
        SystemNavigator.pop();
    }
  }
}

/// Represents the action to take for a back navigation event.
enum BackNavigationAction {
  /// Navigate to a specific route.
  navigateTo,
  /// Show the "swipe again to exit" confirmation.
  showExitConfirmation,
  /// Exit the application.
  exitApp,
}

/// The result of computing a back navigation action.
class BackNavigationResult {
  final BackNavigationAction action;
  final String? targetRoute;

  const BackNavigationResult._({
    required this.action,
    this.targetRoute,
  });

  factory BackNavigationResult.navigateTo(String route) {
    return BackNavigationResult._(
      action: BackNavigationAction.navigateTo,
      targetRoute: route,
    );
  }

  factory BackNavigationResult.showExitConfirmation() {
    return const BackNavigationResult._(
      action: BackNavigationAction.showExitConfirmation,
    );
  }

  factory BackNavigationResult.exitApp() {
    return const BackNavigationResult._(
      action: BackNavigationAction.exitApp,
    );
  }
}
