import 'package:flutter/material.dart';
import 'package:saber/design_system/spacing.dart';
import 'package:saber/design_system/typography.dart';

/// Enhanced empty state component with illustration and contextual actions
/// Provides better user guidance than generic empty messages
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? illustration;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustration,
    this.iconColor,
  });

  /// Empty state for no patients
  factory EmptyState.noPatients({
    Key? key,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      key: key,
      icon: Icons.person_search_outlined,
      title: 'No Patients Yet',
      message:
          'Start by adding your first patient to begin managing their care.',
      actionLabel: actionLabel ?? 'Add Patient',
      onAction: onAction,
      iconColor: Colors.blue,
    );
  }

  /// Empty state for no consultations
  factory EmptyState.noConsultations({
    Key? key,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      key: key,
      icon: Icons.calendar_today_outlined,
      title: 'No Consultations Scheduled',
      message:
          'Your calendar is clear. Schedule a consultation to get started.',
      actionLabel: actionLabel ?? 'Schedule Consultation',
      onAction: onAction,
      iconColor: Colors.green,
    );
  }

  /// Empty state for no search results
  factory EmptyState.noResults({Key? key, String? searchQuery}) {
    return EmptyState(
      key: key,
      icon: Icons.search_off_outlined,
      title: 'No Results Found',
      message: searchQuery != null
          ? 'No patients found matching "$searchQuery". Try a different search term.'
          : 'No results found. Try adjusting your search criteria.',
      iconColor: Colors.orange,
    );
  }

  /// Empty state for no data/records
  factory EmptyState.noData({
    Key? key,
    required String title,
    required String message,
    IconData? icon,
  }) {
    return EmptyState(
      key: key,
      icon: icon ?? Icons.inbox_outlined,
      title: title,
      message: message,
      iconColor: Colors.grey,
    );
  }

  /// Empty state for offline mode
  factory EmptyState.offline({
    Key? key,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      key: key,
      icon: Icons.cloud_off_outlined,
      title: 'You\'re Offline',
      message: 'Check your internet connection to access this content.',
      actionLabel: actionLabel ?? 'Retry',
      onAction: onAction,
      iconColor: Colors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration or Icon
            if (illustration != null)
              illustration!
            else
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: effectiveIconColor),
              ),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              title,
              style: AppTypography.headlineSmall(context),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.sm),

            // Message
            Text(
              message,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),

            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact empty state for smaller containers
class CompactEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const CompactEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
