// SyncingButton removed - Nextcloud sync replaced with Supabase
// See SYNAPSEAI_ROADMAP.md Phase 4 for new sync infrastructure

import 'package:flutter/material.dart';

/// Placeholder for sync button - will be reimplemented with Supabase sync
class SyncingButton extends StatelessWidget {
  const SyncingButton({super.key});

  /// Whether to force the button to look tappable (for screenshots).
  @visibleForTesting
  static var forceButtonActive = false;

  @override
  Widget build(BuildContext context) {
    // Return empty widget - sync functionality will be reimplemented
    return const SizedBox.shrink();
  }
}
