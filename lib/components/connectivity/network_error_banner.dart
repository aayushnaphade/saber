import 'package:flutter/material.dart';
import 'package:saber/data/prefs.dart';

class NetworkErrorBanner extends StatelessWidget {
  const NetworkErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: stows.isOnline,
      builder: (context, _) {
        if (stows.isOnline.value) return const SizedBox.shrink();

        return Material(
          elevation: 4,
          color: Theme.of(context).colorScheme.errorContainer,
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
                  Icons.wifi_off,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No internet connection. Some features may be unavailable.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
