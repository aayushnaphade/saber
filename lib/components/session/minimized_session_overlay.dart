import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/data/session_manager.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/main.dart';

class MinimizedSessionOverlay extends StatelessWidget {
  const MinimizedSessionOverlay({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final sessionManager = SessionManager();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isDark 
              ? const Color(0xFF1A1A1A).withOpacity(0.95) 
              : const Color(0xFFF8F9FF).withOpacity(0.98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark 
                ? Colors.white.withOpacity(0.1) 
                : Colors.blue.withOpacity(0.15),
              width: 1.5,
            ),
            gradient: LinearGradient(
              colors: [
                (isDark ? Colors.blue.shade900 : Colors.blue.shade50).withOpacity(0.3),
                (isDark ? Colors.purple.shade900 : Colors.purple.shade50).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              _buildStatusIndicator(colorScheme),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ACTIVE SESSION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sessionManager.patientName ?? 'Unknown Patient',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                context, 
                'Restore', 
                Icons.open_in_full_rounded,
                colorScheme.primary,
                () {
                  debugPrint('Saber: Minimized Restore clicked');
                  final path = sessionManager.activeSession!.filePath;
                  final consultationId = sessionManager.consultationId;
                  
                  router.push(RoutePaths.editFilePath(
                    path,
                    consultationId: consultationId,
                  ));
                  sessionManager.restore();
                }
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                context, 
                'End', 
                Icons.close_rounded,
                colorScheme.error,
                () {
                  debugPrint('Saber: Minimized End clicked');
                  _showTerminateDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(ColorScheme colorScheme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.edit_note_rounded, color: colorScheme.primary, size: 28),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, 
    String label, 
    IconData icon, 
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint('Saber: ActionButton $label clicked');
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTerminateDialog(BuildContext context) {
    final targetContext = App.rootNavigatorKey.currentContext ?? context;
    
    showDialog(
      context: targetContext,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Terminate Session?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to end this session? Any unsaved changes will be permanently lost.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Keep Writing',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        SessionManager().terminate();
                        Navigator.pop(dialogContext);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Terminate',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
