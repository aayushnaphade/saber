import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/models/previous_session_note.dart';
import 'package:saber/data/supabase/supabase_consultation_service.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';
import 'package:saber/data/supabase/supabase_report_service.dart';
import 'package:saber/data/utils/report_printer.dart';
import 'package:saber/pages/editor/report_view.dart';
// import 'package:saber/data/models/patient.dart'; // SessionInfo already imported

class SessionViewerPage extends StatefulWidget {
  final String patientId;
  final int initialSessionNumber;
  final List<SessionInfo> allSessions;

  const SessionViewerPage({
    super.key,
    required this.patientId,
    required this.initialSessionNumber,
    required this.allSessions,
  });

  @override
  State<SessionViewerPage> createState() => _SessionViewerPageState();
}

class _SessionViewerPageState extends State<SessionViewerPage> {
  static final log = Logger('SessionViewerPage');

  late int _currentSessionNumber;
  ClinicalReport? _currentReport;
  PreviousSessionNote? _currentNote;
  Patient? _patient;
  var _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentSessionNumber = widget.initialSessionNumber;
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = widget.allSessions.firstWhere(
        (s) => s.sessionNumber == _currentSessionNumber,
      );

      // 1. Fetch AI Report
      // The sourceDocumentPath matches the session file path
      // e.g. /patients/{patientId}/session_notes/session_{num}/session_{num}_notes.sbn
      final expectedPath =
          '/patients/${widget.patientId}/session_notes/${session.folderName}/${session.folderName}_notes.sbn';
      log.info('Fetching report for path: $expectedPath');

      final report = await SupabaseReportService.getReportBySourcePath(
        expectedPath,
      );

      // 2. Fetch Handwritten Note Preview
      // Use efficient single-fetch instead of loading all historic notes
      final note = await SupabaseConsultationService.getSessionNote(
        widget.patientId,
        _currentSessionNumber,
      );

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
    final sessionIndices = widget.allSessions
        .map((s) => s.sessionNumber)
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
            'Session $_currentSessionNumber Records',
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
                  Colors.white.withOpacity(0.8),
                  Colors.white.withOpacity(0.0),
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
            if (_currentReport != null)
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
                        // Portrait Mode: Vertical Stack
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top: Handwritten Note
                              if (_currentNote != null)
                                Center(
                                  child: SizedBox(
                                    height: 400, // Fixed height for portrait
                                    child: AspectRatio(
                                      aspectRatio: 1 / 1.414,
                                      child: _buildNoteContainer(),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Text(
                                      'No handwritten note available',
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 32),

                              // Bottom: AI Report
                              if (_currentReport != null)
                                SizedBox(
                                  height:
                                      500, // Give fixed height in portrait scroll
                                  child: _buildReportSection(
                                    theme,
                                    isPortrait: true,
                                  ),
                                )
                              else
                                _buildNoReportState(theme),

                              const SizedBox(height: 100), // Bottom padding
                            ],
                          ),
                        );
                      } else {
                        // Landscape Mode: Horizontal Row
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left: Handwritten Note
                            if (_currentNote != null)
                              SizedBox(
                                width: 500,
                                child: Center(
                                  child: AspectRatio(
                                    aspectRatio: 1 / 1.414,
                                    child: _buildNoteContainer(),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(
                                width: 500,
                                child: Center(
                                  child: Text('No handwritten note available'),
                                ),
                              ),

                            const SizedBox(width: 32),

                            // Right: AI Report
                            Expanded(
                              child: _currentReport != null
                                  ? _buildReportSection(
                                      theme,
                                      isPortrait: false,
                                    )
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

  Widget _buildNoteContainer() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InteractiveViewer(
          maxScale: 5.0,
          child: Image.network(
            _currentNote!.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loading) {
              if (loading == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stack) => const Center(
              child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportSection(ThemeData theme, {required bool isPortrait}) {
    final isDark = theme.brightness == Brightness.dark;
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
