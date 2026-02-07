import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/navbar/responsive_navbar.dart';
import 'package:saber/components/session/minimized_session_overlay.dart';
import 'package:saber/components/settings/update_manager.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/data/services/back_navigation_service.dart';
import 'package:saber/data/session_manager.dart';
import 'package:saber/i18n/strings.g.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.child,
    required this.subpage,
    this.navigatorKey,
    this.currentPath,
  });

  final Widget child;
  final String subpage;
  final GlobalKey<NavigatorState>? navigatorKey;
  final String? currentPath;

  @override
  State<HomePage> createState() => _HomePageState();

  static const dashboardSubpage = 'dashboard';
  static const recentSubpage = 'recent';
  static const browseSubpage = 'browse';
  static const whiteboardSubpage = 'whiteboard';
  static const settingsSubpage = 'settings';
  static const historySubpage = 'history';
  static const teamManagementSubpage = 'team';
  static const professionalSubpage = 'professional';
  static const appSettingsSubpage = 'app_settings';
  static const subpages = [
    dashboardSubpage,
    recentSubpage,
    browseSubpage,
    whiteboardSubpage,
    settingsSubpage,
  ];
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    DynamicMaterialApp.addFullscreenListener(_setState);
    super.initState();
    _showDialogs();
  }

  void _showDialogs() async {
    await null; // initState must be completed before using context
    if (!mounted) return;
    UpdateManager.showUpdateDialog(context);
    // SentryConsentDialog.showIfNeeded(context);
  }

  void _setState() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset exit timer when navigating to a different subpage
    if (oldWidget.subpage != widget.subpage ||
        oldWidget.currentPath != widget.currentPath) {
      BackNavigationService.resetExitTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = HomePage.subpages.indexOf(widget.subpage);

    final child =
        (widget.subpage == HomePage.whiteboardSubpage &&
            DynamicMaterialApp.isFullscreen)
        ? widget.child
        : ResponsiveNavbar(
            selectedIndex: index == -1 ? null : index,
            body: widget.child,
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final path = widget.currentPath ?? GoRouterState.of(context).uri.path;

        // Use BackNavigationService to determine the correct navigation action
        final navResult = BackNavigationService.getBackNavigationResult(
          currentPath: path,
          currentSubpage: widget.subpage,
        );
        debugPrint(
          'HomePage: PopScope triggered. Path: $path, Subpage: ${widget.subpage}',
        );
        debugPrint(
          'HomePage: BackNavigationService result: ${navResult.action}, Target: ${navResult.targetRoute}',
        );

        BackNavigationService.executeBackNavigation(
          context,
          navResult,
          t.common.backAgainToExit,
        );
      },
      child: Stack(
        children: [
          child,
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ListenableBuilder(
              listenable: SessionManager(),
              builder: (context, _) {
                final sessionManager = SessionManager();
                final bool isVisible =
                    sessionManager.hasActiveSession &&
                    sessionManager.isMinimized;

                if (isVisible) {
                  return MinimizedSessionOverlay(
                    key: const ValueKey('session_bar'),
                    router: GoRouter.of(context),
                  );
                }
                return const SizedBox.shrink(key: ValueKey('empty_bar'));
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    DynamicMaterialApp.removeFullscreenListener(_setState);
    super.dispose();
  }
}
