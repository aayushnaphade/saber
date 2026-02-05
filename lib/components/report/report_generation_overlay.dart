import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/animations/mesh_orb.dart';
import 'package:saber/data/report_generation_manager.dart';
import 'package:saber/data/session_manager.dart';
import 'package:saber/data/supabase/supabase_report_service.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/pages/editor/report_view.dart';
import 'package:saber/main.dart';

class ReportGenerationOverlay extends StatefulWidget {
  const ReportGenerationOverlay({
    super.key,
    required this.child,
    this.onReview,
  });

  final Widget child;
  final Function(Map<String, dynamic> reportData)? onReview;

  @override
  State<ReportGenerationOverlay> createState() =>
      _ReportGenerationOverlayState();
}

class _ReportGenerationOverlayState extends State<ReportGenerationOverlay> {
  Offset _position = const Offset(-1, -1); // -1 means use default

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ListenableBuilder(
          listenable: ReportGenerationManager(),
          builder: (context, _) {
            final manager = ReportGenerationManager();
            if (manager.status == ReportGenerationStatus.idle) {
              return const SizedBox.shrink();
            }

            final mediaQuery = MediaQuery.of(context);
            if (_position.dx == -1) {
              _position = Offset(
                mediaQuery.size.width - 344,
                mediaQuery.size.height -
                    300, // Move higher to avoid blocking minimized session bar
              );
            }

            return Positioned(
              left: _position.dx,
              top: _position.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _position += details.delta;
                    // Keep within bounds
                    _position = Offset(
                      _position.dx.clamp(20, mediaQuery.size.width - 340),
                      _position.dy.clamp(20, mediaQuery.size.height - 180),
                    );
                  });
                },
                child: _AsyncReportCard(
                  manager: manager,
                  onReview: widget.onReview,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AsyncReportCard extends StatefulWidget {
  const _AsyncReportCard({required this.manager, this.onReview});

  final ReportGenerationManager manager;
  final Function(Map<String, dynamic> reportData)? onReview;

  @override
  State<_AsyncReportCard> createState() => _AsyncReportCardState();
}

class _AsyncReportCardState extends State<_AsyncReportCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  int _messageIndex = 0;
  final List<String> _reassuranceMessages = [
    'Synapse AI is thinking...',
    'Analyzing session notes...',
    'Generating clinical insights...',
    'Finalizing report...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _progressController.addListener(() {
      final newIndex = (_progressController.value * _reassuranceMessages.length)
          .floor()
          .clamp(0, _reassuranceMessages.length - 1);
      if (newIndex != _messageIndex) {
        setState(() {
          _messageIndex = newIndex;
        });
      }
    });

    if (widget.manager.status == ReportGenerationStatus.processing) {
      _progressController.forward();
    }
  }

  @override
  void didUpdateWidget(_AsyncReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.manager.status == ReportGenerationStatus.processing &&
        oldWidget.manager.status != ReportGenerationStatus.processing) {
      _progressController.reset();
      _progressController.forward();
    } else if (widget.manager.status == ReportGenerationStatus.completed) {
      _progressController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final brandColors = [
      const Color(0xFF0A4D8B), // Navy
      const Color(0xFF50B9E8), // Sky
      const Color(0xFF10B981), // Emerald
      const Color(0xFF0D9488), // Deep Teal
      const Color(0xFFFFFFFF), // White
    ];

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: widget.manager.status == ReportGenerationStatus.completed
            ? () {
                if (widget.onReview != null &&
                    widget.manager.reportData != null) {
                  widget.onReview!(widget.manager.reportData!);
                } else {
                  _showReport(context);
                }
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: widget.manager.status == ReportGenerationStatus.error
                  ? Colors.red.withValues(alpha: 0.3)
                  : colorScheme.primary.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (widget.manager.status == ReportGenerationStatus.error
                            ? Colors.red
                            : colorScheme.primary)
                        .withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildOrb(brandColors),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.manager.status == ReportGenerationStatus.error
                              ? 'GENERATION FAILED'
                              : widget.manager.status ==
                                    ReportGenerationStatus.completed
                              ? 'REPORT READY'
                              : 'AI PROCESSING',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                widget.manager.status ==
                                    ReportGenerationStatus.error
                                ? Colors.red
                                : colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.manager.patient?.fullName ??
                              'Processing session...',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.manager.status ==
                          ReportGenerationStatus.completed ||
                      widget.manager.status == ReportGenerationStatus.error)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => _showCancelConfirmation(context),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.manager.status == ReportGenerationStatus.processing)
                _buildProgressBar(colorScheme),
              if (widget.manager.status == ReportGenerationStatus.completed)
                _buildSuccessAction(colorScheme),
              if (widget.manager.status == ReportGenerationStatus.error)
                Text(
                  widget.manager.errorMessage ?? 'An unexpected error occurred',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              Text(
                widget.manager.status == ReportGenerationStatus.processing
                    ? _reassuranceMessages[_messageIndex]
                    : widget.manager.currentMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrb(List<Color> colors) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (widget.manager.status == ReportGenerationStatus.processing)
            BoxShadow(
              color: colors[1].withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
        ],
      ),
      child: widget.manager.status == ReportGenerationStatus.processing
          ? MeshOrb(
              size: 60,
              colors: colors,
              duration: const Duration(seconds: 8),
            )
          : Icon(
              widget.manager.status == ReportGenerationStatus.completed
                  ? Icons.check_circle_rounded
                  : widget.manager.status == ReportGenerationStatus.error
                  ? Icons.error_rounded
                  : Icons.auto_awesome,
              color: widget.manager.status == ReportGenerationStatus.completed
                  ? Colors.green
                  : widget.manager.status == ReportGenerationStatus.error
                  ? Colors.red
                  : colors[0],
              size: 32,
            ),
    );
  }

  Widget _buildProgressBar(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                value: _progressController.value,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progressController.value * 100).toInt()}% Analysing Session',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuccessAction(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
        label: const Text('Review & Save'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          if (widget.onReview != null && widget.manager.reportData != null) {
            widget.onReview!(widget.manager.reportData!);
          } else {
            _showReport(context);
          }
        },
      ),
    );
  }

  void _showReport(BuildContext context) {
    final reportData = widget.manager.reportData;
    if (reportData == null) return;

    // Use root navigator context because the overlay might be outside the local navigator tree
    final targetContext = App.rootNavigatorKey.currentContext ?? context;

    showDialog(
      context: targetContext,
      builder: (context) => Dialog(
        alignment: Alignment.center,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: ReportView(
              reportData: reportData,
              patient: widget.manager.patient,
              rawNotes: widget.manager.rawNotes,
              imageBytesList: widget.manager.imageBytesList,
              onVerify: () async {
                final manager = widget.manager;
                final reportData = manager.reportData;
                final patient = manager.patient;

                if (reportData != null && patient != null) {
                  try {
                    // 1. Save to Supabase
                    final sb = StringBuffer();
                    sb.writeln('# Clinical Report: ${patient.fullName}');
                    sb.writeln(
                      'Date: ${DateTime.now().toString().split(' ')[0]}',
                    );
                    sb.writeln('\n## Summary');
                    sb.writeln(reportData['summary'] ?? 'No summary available');

                    // Use live file path from SessionManager if available, fallback to manager's captured path
                    var finalSourcePath =
                        SessionManager().activeSession?.filePath ??
                        manager.filePath;

                    // Ensure the path has the correct extension for lookup in history
                    if (finalSourcePath != null &&
                        !finalSourcePath.endsWith('.sbn')) {
                      if (finalSourcePath.endsWith('.sbn2')) {
                        finalSourcePath = finalSourcePath.replaceAll(
                          '.sbn2',
                          '.sbn',
                        );
                      } else {
                        finalSourcePath = '$finalSourcePath.sbn';
                      }
                    }

                    await SupabaseReportService.createReport(
                      patientId: patient.id,
                      structuredData: reportData,
                      markdownContent: sb.toString(),
                      sourceDocumentPath: finalSourcePath,
                    );

                    // 2. Terminate Session properly
                    await SessionManager().deleteActiveSessionFiles();
                    SessionManager().terminate();

                    // 3. Clear manager state
                    manager.reset();

                    // 4. Return to Dashboard
                    if (context.mounted) {
                      Navigator.of(context).pop(); // Close dialog
                      context.go(HomeRoutes.getRoute(0)); // Go to dashboard
                    }
                  } catch (e) {
                    final targetContext =
                        App.rootNavigatorKey.currentContext ?? context;
                    if (targetContext.mounted) {
                      ScaffoldMessenger.of(targetContext).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save and terminate: $e'),
                        ),
                      );
                    }
                  }
                } else {
                  Navigator.of(context).pop();
                  manager.reset();
                }
              },
              onRegenerate: () {
                Navigator.pop(context);
                widget.manager.startGeneration(
                  imageBytesList: widget.manager.imageBytesList,
                  patient: widget.manager.patient,
                  filePath: widget.manager.filePath,
                  rawNotes: widget.manager.rawNotes,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context) {
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
                color: Colors.black.withValues(alpha: 0.2),
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
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Cancel Report?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to discard this AI report? You will need to regenerate it if you close it now.',
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Keep Report',
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
                        Navigator.pop(dialogContext);
                        widget.manager.reset();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Discard',
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
