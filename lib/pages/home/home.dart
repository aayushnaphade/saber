import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:saber/components/home/sentry_consent_dialog.dart';
import 'package:saber/components/navbar/responsive_navbar.dart';
import 'package:saber/components/settings/update_manager.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/pages/home/dashboard/dashboard_page.dart';
import 'package:saber/pages/home/dashboard/consultation_history_page.dart';
import 'package:saber/pages/home/patient_browse.dart';
import 'package:saber/pages/home/recent_notes.dart';
import 'package:saber/pages/home/settings.dart';
import 'package:saber/pages/home/whiteboard.dart';
import 'package:saber/pages/home/dashboard/team_management_page.dart';

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
    return ResponsiveNavbar(
      selectedIndex: index == -1 ? null : index,
      body: widget.child,
    );
  }

  @override
  void dispose() {
    DynamicMaterialApp.removeFullscreenListener(_setState);
    super.dispose();
  }
}
