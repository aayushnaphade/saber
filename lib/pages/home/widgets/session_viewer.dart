import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/models/previous_session_note.dart';
import 'package:saber/data/repositories/session_data_repository.dart';
import 'package:saber/data/supabase/supabase_consultation_service.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';
import 'package:saber/data/supabase/supabase_report_service.dart';
import 'package:saber/data/utils/report_printer.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/editor/report_view.dart';

class SessionViewerPage extends StatefulWidget {
  final String patientId;
  final int initialSessionNumber;
  final List<SessionInfo>? allSessions;
  final bool viewOnlyNotes;

  const SessionViewerPage({
    super.key,
    required this.patientId,
    required this.initialSessionNumber,
    this.allSessions,
    this.viewOnlyNotes = false,
  });

  @override
  State<SessionViewerPage> createState() => _SessionViewerPageState();
}

class _SessionViewerPageState extends State<SessionViewerPage> {
  static final log = Logger('SessionViewerPage');

  late int _currentSessionNumber;
  late List<SessionInfo> _sessions;
  ClinicalReport? _currentReport;
  PreviousSessionNote? _currentNote;
  Patient? _patient;
  var _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentSessionNumber = widget.initialSessionNumber;
    _sessions = List.from(widget.allSessions ?? []);
    _loadSessionData();

    // If we only have one session, fetch all to enable navigation
    if (_sessions.length <= 1) {
      _fetchAllSessions();
    }
  }

  Future<void> _fetchAllSessions() async {
    try {
      final reports = await SupabaseReportService.getReportsForPatient(
        widget.patientId,
      );
      final newSessions = <SessionInfo>{};

      for (final report in reports) {
        final sessionMatch = RegExp(
          r'session_(\d+)',
        ).firstMatch(report.sourceDocumentPath ?? '');
        if (sessionMatch != null) {
          final num = int.parse(sessionMatch.group(1)!);
          newSessions.add(
            SessionInfo(
              sessionNumber: num,
              folderName: 'session_$num',
              fileCount: 0,
              createdDate: report.createdAt,
            ),
          );
        }
      }

      if (mounted && newSessions.isNotEmpty) {
        setState(() {
          _sessions = newSessions.toList();
        });
      }
    } catch (e) {
      log.warning('Failed to fetch all sessions for patient: $e');
    }
  }

  Future<void> _loadSessionData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = _sessions.firstWhere(
        (s) => s.sessionNumber == _currentSessionNumber,
      );

      // 1. Fetch AI Report
      // The sourceDocumentPath matches the session file path
      // e.g. /patients/{patientId}/session_notes/session_{num}/session_{num}_notes.sbn2
      final documentName = '${session.folderName}_notes';
      final expectedPath =
          '/patients/${widget.patientId}/session_notes/${session.folderName}/$documentName${Editor.extension}';
      // Also check for legacy .sbn paths from older sessions
      final legacyPath =
          '/patients/${widget.patientId}/session_notes/${session.folderName}/$documentName.sbn';
      log.info(
        'Fetching report for patient ${widget.patientId}, session folder ${session.folderName}',
      );
      log.info('Expected path: $expectedPath (legacy: $legacyPath)');

      // Robust fetch: get all reports for patient and filter in Dart
      // to handle potential path mismatch or extension variation (.sbn vs .sbn2)
      log.info('Fetching all reports for patient ${widget.patientId}');
      final allReports = await SupabaseReportService.getReportsForPatient(
        widget.patientId,
      );
      log.info('Found ${allReports.length} total reports for this patient');
      if (allReports.isNotEmpty) {
        log.info('First report path: ${allReports.first.sourceDocumentPath}');
      }

      ClinicalReport? report;
      try {
        report = allReports.firstWhere(
          (r) =>
              r.sourceDocumentPath == expectedPath ||
              r.sourceDocumentPath == legacyPath ||
              (r.sourceDocumentPath?.contains(session.folderName) ?? false),
        );
        log.info('Found matching report: ${report.id}');
      } catch (e) {
        log.warning(
          'No matching report found after filtering ${allReports.length} reports',
        );
        // Fallback to direct path search (try both extensions)
        report = await SupabaseReportService.getReportBySourcePath(
          expectedPath,
        );
        report ??= await SupabaseReportService.getReportBySourcePath(
          legacyPath,
        );
      }

      // 2. Fetch Handwritten Note Preview
      PreviousSessionNote? note;
      try {
        final thumbPath = await SessionDataRepository.getThumbnailPath(
          expectedPath,
        );
        if (thumbPath != null) {
          final file = File(thumbPath);
          log.info('Found note preview at $thumbPath');
          note = PreviousSessionNote(
            pageUrls: [thumbPath],
            sessionNumber: _currentSessionNumber,
            createdAt: await file.lastModified(),
            fileName: p.basename(thumbPath),
            pageCount: 1,
          );
        }
      } catch (e) {
        log.warning('Error resolving thumbnail via repository: $e');
      }

      if (note == null) {
        log.info(
          'Fetching session note from Supabase for session $_currentSessionNumber...',
        );
        try {
          note = await SupabaseConsultationService.getSessionNote(
            widget.patientId,
            _currentSessionNumber,
            doctorId: report?.doctorId, // Pass the doctorId from the report
          );
          if (note != null) {
            log.info(
              'Successfully fetched note from Supabase: ${note.fileName}',
            );
          } else {
            log.warning(
              'No note found in Supabase for session $_currentSessionNumber',
            );
          }
        } catch (e) {
          log.severe(
            'Error fetching session note for session $_currentSessionNumber: $e',
          );
        }
      }

      // 3. Fetch Patient Info
      final patient = await SupabasePatientService.getPatient(widget.patientId);

      if (mounted) {
        setState(() {
          _currentReport = report;
          _currentNote = note;
          _patient = patient;
          _isLoading = false;
        });
      }
    } catch (e) {
      log.severe('Error loading session data', e);
      if (mounted) {
        setState(() {
          _error = ErrorHandler.getFriendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToSession(int sessionNumber) {
    if (sessionNumber == _currentSessionNumber) return;
    setState(() {
      _currentSessionNumber = sessionNumber;
    });
    _loadSessionData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionIndices = _sessions
        .map((s) => s.sessionNumber)
        .toSet()
        .toList();
    sessionIndices.sort((a, b) => b.compareTo(a)); // Newest first

    final currentIndex = sessionIndices.indexOf(_currentSessionNumber);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (currentIndex > 0) {
            _navigateToSession(sessionIndices[currentIndex - 1]);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (currentIndex < sessionIndices.length - 1) {
            _navigateToSession(sessionIndices[currentIndex + 1]);
          }
        },
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            widget.viewOnlyNotes
                ? 'Session $_currentSessionNumber Notes'
                : 'Session $_currentSessionNumber Records',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: currentIndex > 0
                  ? () => _navigateToSession(sessionIndices[currentIndex - 1])
                  : null,
              tooltip: 'Newer Session',
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '${currentIndex + 1} of ${sessionIndices.length}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: currentIndex < sessionIndices.length - 1
                  ? () => _navigateToSession(sessionIndices[currentIndex + 1])
                  : null,
              tooltip: 'Older Session',
            ),
            if (_currentReport != null && !widget.viewOnlyNotes)
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () => ReportPrinter.printReport(
                  _currentReport!.structuredData,
                  generatedAt: _currentReport!.createdAt,
                  patient: _patient,
                ),
                tooltip: 'Print PDF',
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.brightness == Brightness.dark
                  ? [
                      const Color(0xFF121212), // Deep black-grey
                      const Color(0xFF1E1E1E),
                    ]
                  : [
                      const Color(0xFFF5F7FA), // Very light grey
                      const Color(0xFFE4EBF5), // Subtle blue-grey
                    ],
            ),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(_error!, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSessionData,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    100,
                    24,
                    24,
                  ), // Top padding for transparent AppBar
                  // Responsive layout based on orientation
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isPortrait =
                          constraints.maxHeight > constraints.maxWidth;

                      if (isPortrait) {
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Handwritten Note Section
                              if (_currentNote != null &&
                                  _currentNote!.pageUrls.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Handwritten Notes (${_currentNote!.pageUrls.length} pages)',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 540,
                                      child: PageView.builder(
                                        itemCount:
                                            _currentNote!.pageUrls.length,
                                        itemBuilder: (context, index) {
                                          return _buildNotePage(
                                            _currentNote!,
                                            index,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Text(
                                      'No handwritten notes available',
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 32),

                              // AI Report Section
                              if (!widget.viewOnlyNotes)
                                if (_currentReport != null)
                                  SizedBox(
                                    height: 500,
                                    child: _buildReportSection(theme),
                                  )
                                else
                                  _buildNoReportState(theme),

                              const SizedBox(height: 80),
                            ],
                          ),
                        );
                      } else {
                        // Landscape Mode
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left: Notes
                            if (_currentNote != null &&
                                _currentNote!.pageUrls.isNotEmpty)
                              SizedBox(
                                width: constraints.maxWidth * 0.45,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Handwritten Notes (${_currentNote!.pageUrls.length} pages)',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: PageView.builder(
                                        itemCount:
                                            _currentNote!.pageUrls.length,
                                        itemBuilder: (context, index) {
                                          return _buildNotePage(
                                            _currentNote!,
                                            index,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Expanded(
                                child: Center(
                                  child: Text('No handwritten notes available'),
                                ),
                              ),

                            const SizedBox(width: 32),

                            // Right: AI Report
                            if (!widget.viewOnlyNotes)
                              Expanded(
                                child: _currentReport != null
                                    ? _buildReportSection(theme)
                                    : _buildNoReportState(theme),
                              ),
                          ],
                        );
                      }
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNotePage(PreviousSessionNote note, int index) {
    if (index >= note.pageUrls.length) return const SizedBox.shrink();
    final url = note.pageUrls[index];

    return Column(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: url.startsWith('http')
                    ? Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Icon(Icons.broken_image)),
                      )
                    : Builder(
                        builder: (context) {
                          final file = File(url);
                          // Force eviction of the old image from cache before displaying
                          // This is crucial because the file path stays the same when the thumbnail is updated
                          FileImage(file).evict();
                          return Image.file(
                            file,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(child: Icon(Icons.broken_image)),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Page ${index + 1} of ${note.pageUrls.length}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildReportSection(ThemeData theme) {
    if (_currentReport == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Generated: ${DateFormat('dd MMM yyyy, h:mm a').format(_currentReport!.createdAt)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
        Expanded(
          child: ReportView(
            reportData: _currentReport!.structuredData,
            onVerify: () {},
            readonly: true,
            showAppBar: false,
            patient: _patient,
          ),
        ),
      ],
    );
  }

  Widget _buildNoReportState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 64,
            color: Colors.indigo.shade100,
          ),
          const SizedBox(height: 24),
          Text(
            'No AI report generated for this session',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
