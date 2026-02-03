import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/components/navbar/responsive_navbar.dart';
import 'package:saber/components/settings/update_manager.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.child, required this.subpage});

  final Widget child;
  final String subpage;

  @override
  State<HomePage> createState() => _HomePageState();

  static const dashboardSubpage = 'dashboard';
  static const recentSubpage = 'recent';
  static const browseSubpage = 'browse';
  static const whiteboardSubpage = 'whiteboard';
  static const settingsSubpage = 'settings';
  static const historySubpage = 'history';
  static const teamManagementSubpage = 'team';
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

  static DateTime? _lastBackPressTime;

  void _setState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // hide navbar in fullscreen whiteboard
    if (widget.subpage == HomePage.whiteboardSubpage &&
        DynamicMaterialApp.isFullscreen) {
      return widget.child;
    }

    final index = HomePage.subpages.indexOf(widget.subpage);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Try to pop nested routes/dialogs first
        // Note: Navigator.of(context) inside HomePage (shell) refers to
        // the shell's parent navigator (Root Navigator).
        // To check for popped overlays (like dialogs), this is usually correct.
        // But we must be careful not to pop the Shell itself unless we intend to.
        // Actually, GoRouter handles Shell popping.
        // If we use Navigator.canPop(), it checks if there is history.
        // If we are at the top of the route stack (e.g. /home/settings replaced history),
        // canPop() might be false.

        // However, if a dialog is open, canPop() is true.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        // If not on dashboard, go to dashboard
        if (widget.subpage != HomePage.dashboardSubpage) {
          context.go(HomeRoutes.getRoute(0));
          return;
        }

        // Double back to exit logic on dashboard
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.common.backAgainToExit),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Exit the app
          SystemNavigator.pop();
        }
      },
      child: ResponsiveNavbar(
        selectedIndex: index == -1 ? null : index,
        body: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    DynamicMaterialApp.removeFullscreenListener(_setState);
    super.dispose();
  }
}
