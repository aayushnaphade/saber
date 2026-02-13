import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saber/data/prefs.dart';

class NetworkErrorBanner extends StatefulWidget {
  const NetworkErrorBanner({super.key});

  @override
  State<NetworkErrorBanner> createState() => _NetworkErrorBannerState();
}

class _NetworkErrorBannerState extends State<NetworkErrorBanner> {
  var _showBackOnline = false;
  var _isMinimized = false;
  Timer? _backOnlineTimer;
  Timer? _minimizeTimer;

  @override
  void initState() {
    super.initState();
    stows.isOnline.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    stows.isOnline.removeListener(_onConnectivityChanged);
    _backOnlineTimer?.cancel();
    _minimizeTimer?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (stows.isOnline.value) {
      // Connection restored, show "Back Online" for 3 seconds
      _minimizeTimer?.cancel();
      setState(() {
        _showBackOnline = true;
        _isMinimized = false;
      });
      _backOnlineTimer?.cancel();
      _backOnlineTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showBackOnline = false;
          });
        }
      });
    } else {
      // Connection lost — show full banner, then minimize after 5 seconds
      setState(() {
        _showBackOnline = false;
        _isMinimized = false;
      });
      _minimizeTimer?.cancel();
      _minimizeTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isMinimized = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: stows.isOnline,
      builder: (context, _) {
        final isOffline = !stows.isOnline.value;
        final showBanner = isOffline || _showBackOnline;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
          child: !showBanner
              ? const SizedBox.shrink()
              : isOffline && _isMinimized
              ? GestureDetector(
                  key: const ValueKey('offline-minimized'),
                  onTap: () {
                    // Tap to temporarily expand the banner
                    setState(() => _isMinimized = false);
                    _minimizeTimer?.cancel();
                    _minimizeTimer = Timer(const Duration(seconds: 4), () {
                      if (mounted && !stows.isOnline.value) {
                        setState(() => _isMinimized = true);
                      }
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    height: 4,
                    color: Theme.of(context).colorScheme.error,
                  ),
                )
              : Material(
                  key: ValueKey(isOffline ? 'offline' : 'online'),
                  elevation: 4,
                  color: isOffline
                      ? Theme.of(context).colorScheme.errorContainer
                      : const Color(0xFF10B981),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      bottom: 8,
                      left: 16,
                      right: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOffline ? Icons.wifi_off : Icons.wifi,
                          color: isOffline
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isOffline
                                ? 'No internet connection. Some features may be unavailable.'
                                : 'Back Online',
                            style: TextStyle(
                              color: isOffline
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
