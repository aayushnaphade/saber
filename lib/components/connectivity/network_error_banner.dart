import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saber/data/prefs.dart';

class NetworkErrorBanner extends StatefulWidget {
  const NetworkErrorBanner({super.key});

  @override
  State<NetworkErrorBanner> createState() => _NetworkErrorBannerState();
}

class _NetworkErrorBannerState extends State<NetworkErrorBanner> {
  bool _showBackOnline = false;
  Timer? _backOnlineTimer;

  @override
  void initState() {
    super.initState();
    stows.isOnline.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    stows.isOnline.removeListener(_onConnectivityChanged);
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (stows.isOnline.value) {
      // Connection restored, show "Back Online" for 3 seconds
      setState(() {
        _showBackOnline = true;
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
      // Connection lost, hide "Back Online" if it was showing
      setState(() {
        _showBackOnline = false;
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
