import 'package:flutter/material.dart';

// Nextcloud sync removed - indicator disabled until Supabase sync is implemented
class SyncIndicator extends StatefulWidget {
  const SyncIndicator({super.key, required this.filePath});

  final String filePath;

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator> {
  final status = ValueNotifier(_SyncIndicatorStatus.done);

  @override
  void initState() {
    super.initState();
    // TODO: Implement Supabase sync status monitoring
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: IgnorePointer(
        child: Padding(
          padding: const .all(8),
          child: ValueListenableBuilder(
            valueListenable: status,
            builder: (context, status, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (status) {
                  .done => null,
                  .uploading => const Icon(Icons.upload),
                  .downloading => const Icon(Icons.download),
                  .merging => const Icon(Icons.sync),
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    status.dispose();
    super.dispose();
  }
}

enum _SyncIndicatorStatus { done, uploading, downloading, merging }
