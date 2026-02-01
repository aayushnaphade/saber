import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/navbar/horizontal_navbar.dart';
import 'package:saber/components/navbar/vertical_navbar.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:stow_codecs/stow_codecs.dart';

class ResponsiveNavbar extends StatefulWidget {
  const ResponsiveNavbar({
    super.key,
    required this.body,
    this.selectedIndex,
  });

  final Widget body;
  final int? selectedIndex;

  @override
  State<ResponsiveNavbar> createState() => _ResponsiveNavbarState();

  static var isLargeScreen = true;
}

class _ResponsiveNavbarState extends State<ResponsiveNavbar> {
  DateTime? _lastTapTime;
  static const _tapDebounceMs = 300;
  bool _isNavigating = false;

  @override
  void initState() {
    stows.locale.addListener(onChange);
    stows.layoutSize.addListener(onChange);
    stows.receptionMode.addListener(onChange);
    super.initState();
  }

  void onChange() {
    setState(() {});
  }

  void onDestinationSelected(int index) {
    if (index == widget.selectedIndex) return;

    // Prevent navigation if already navigating
    if (_isNavigating) return;

    // Debounce rapid taps to prevent double visual feedback
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < _tapDebounceMs) {
      return;
    }
    _lastTapTime = now;

    _isNavigating = true;
    context.go(HomeRoutes.getRoute(index));
    
    // Reset navigation flag after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _isNavigating = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    ResponsiveNavbar.isLargeScreen = switch (stows.layoutSize.value) {
      .auto => mediaQuery.size.width >= 600,
      .phone => false,
      .tablet => true,
    };

    if (ResponsiveNavbar.isLargeScreen) {
      return Scaffold(
        body: Row(
          children: [
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: VerticalNavbar(
                  destinations: HomeRoutes.navigationRailDestinations,
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                ),
              ),
            ),
            Expanded(child: widget.body),
          ],
        ),
      );
    } // else mobile

    final navbarClearance = HorizontalNavbar.clearanceHeightOf(context);
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          MediaQuery(
            data: mediaQuery.copyWith(
              padding: mediaQuery.padding + .only(bottom: navbarClearance),
              viewPadding:
                  mediaQuery.viewPadding + .only(bottom: navbarClearance),
            ),
            child: widget.body,
          ),
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: HorizontalNavbar(
              destinations: HomeRoutes.navigationDestinations,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: onDestinationSelected,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    stows.locale.removeListener(onChange);
    stows.layoutSize.removeListener(onChange);
    super.dispose();
  }
}

enum LayoutSize {
  auto,
  phone,
  tablet;

  static const codec = EnumCodec(values);
}
