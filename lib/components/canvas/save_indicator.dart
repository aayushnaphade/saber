import 'package:flutter/material.dart';
import 'package:saber/components/theming/adaptive_circular_progress_indicator.dart';

/// Indicates the state of saving in the editor.
/// Now displays as a status pill with automatic feedback.
class SaveIndicator extends StatelessWidget {
  const SaveIndicator({
    super.key,
    required this.savingState,
    required this.triggerSave,
  });

  final ValueNotifier<SavingState> savingState;
  final VoidCallback triggerSave;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: savingState,
      builder: (context, state, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: InkWell(
            onTap: state == SavingState.waitingToSave ? triggerSave : null,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _getBgColor(state, colorScheme),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getBorderColor(state, colorScheme),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIcon(state, colorScheme),
                  const SizedBox(width: 8),
                  Text(
                    _getLabel(state),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _getTextColor(state, colorScheme),
                      letterSpacing: -0.2,
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

  Color _getBgColor(SavingState state, ColorScheme colorScheme) {
    return switch (state) {
      SavingState.waitingToSave =>
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      SavingState.saving => colorScheme.primary.withValues(alpha: 0.08),
      SavingState.saved => Colors.green.withValues(alpha: 0.08),
    };
  }

  Color _getBorderColor(SavingState state, ColorScheme colorScheme) {
    return switch (state) {
      SavingState.waitingToSave => colorScheme.outlineVariant.withValues(
        alpha: 0.2,
      ),
      SavingState.saving => colorScheme.primary.withValues(alpha: 0.2),
      SavingState.saved => Colors.green.withValues(alpha: 0.2),
    };
  }

  Color _getTextColor(SavingState state, ColorScheme colorScheme) {
    return switch (state) {
      SavingState.waitingToSave => colorScheme.onSurfaceVariant.withValues(
        alpha: 0.7,
      ),
      SavingState.saving => colorScheme.primary,
      SavingState.saved => Colors.green.shade700,
    };
  }

  Widget _buildIcon(SavingState state, ColorScheme colorScheme) {
    return switch (state) {
      SavingState.waitingToSave => Icon(
        Icons.cloud_upload_outlined,
        size: 16,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      SavingState.saving => const SizedBox(
        width: 14,
        height: 14,
        child: AdaptiveCircularProgressIndicator(strokeWidth: 2),
      ),
      SavingState.saved => const Icon(
        Icons.cloud_done_rounded,
        size: 16,
        color: Colors.green,
      ),
    };
  }

  String _getLabel(SavingState state) {
    return switch (state) {
      SavingState.waitingToSave => 'Auto-saving...',
      SavingState.saving => 'Saving...',
      SavingState.saved => 'Saved',
    };
  }
}

enum SavingState { waitingToSave, saving, saved }
