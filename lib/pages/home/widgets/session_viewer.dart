import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/models/previous_session_note.dart';
import 'package:saber/data/supabase/supabase_consultation_service.dart';
import 'package:saber/data/supabase/supabase_report_service.dart';
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
  bool _isLoading = true;
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
      final expectedPath = '/patients/${widget.patientId}/session_notes/${session.folderName}/${session.folderName}_notes.sbn';
      log.info('Fetching report for path: $expectedPath');
      
      final report = await SupabaseReportService.getReportBySourcePath(expectedPath);
      
      // 2. Fetch Handwritten Note Preview
      // We can use the getPreviousSessionNotes logic but for this specific session
      final allNotes = await SupabaseConsultationService.getPreviousSessionNotes(widget.patientId);
      final note = allNotes.cast<PreviousSessionNote?>().firstWhere(
        (n) => n?.sessionNumber == _currentSessionNumber,
        orElse: () => null,
      );

      if (mounted) {
        setState(() {
          _currentReport = report;
          _currentNote = note;
          _isLoading = false;
        });
      }
    } catch (e) {
      log.severe('Error loading session data', e);
      if (mounted) {
        setState(() {
          _error = 'Failed to load session documents: $e';
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
    final sessionIndices = widget.allSessions.map((s) => s.sessionNumber).toList();
    sessionIndices.sort((a, b) => b.compareTo(a)); // Newest first
    
    final currentIndex = sessionIndices.indexOf(_currentSessionNumber);
    final hasNext = currentIndex > 0;
    final hasPrev = currentIndex < sessionIndices.length - 1;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Session $_currentSessionNumber Records', style: const TextStyle(fontWeight: FontWeight.w600)),
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
            onPressed: hasPrev ? () => _navigateToSession(sessionIndices[currentIndex + 1]) : null,
            tooltip: 'Older Session',
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                '${currentIndex + 1} of ${sessionIndices.length}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: hasNext ? () => _navigateToSession(sessionIndices[currentIndex - 1]) : null,
            tooltip: 'Newer Session',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
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
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                    padding: const EdgeInsets.fromLTRB(24, 100, 24, 24), // Top padding for transparent AppBar
                    // Responsive layout based on orientation
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isPortrait = constraints.maxHeight > constraints.maxWidth;

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
                                      child: Text('No handwritten note available'),
                                    ),
                                  ),

                                const SizedBox(height: 32),

                                // Bottom: AI Report
                                if (_currentReport != null)
                                  SizedBox(
                                      height: 500, // Give fixed height in portrait scroll
                                      child: _buildReportSection(theme, isPortrait: true)
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
                                    ? _buildReportSection(theme, isPortrait: false)
                                    : _buildNoReportState(theme),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildNoteContainer() {
    return Container(
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
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, 
                size: 24, 
                color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade400
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI Generated Report',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.indigo.shade100 : Colors.indigo.shade900,
                    fontSize: isPortrait ? 20 : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isPortrait) const Spacer(),
              if (!isPortrait)
                Text(
                  'Generated: ${DateFormat.yMMMd().format(_currentReport!.createdAt)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600]
                  ),
                ),
              if (!isPortrait)
                const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.code, size: 20, color: Colors.grey),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Raw Markdown Report'),
                      content: SingleChildScrollView(
                        child: SelectableText(
                          _currentReport!.markdownContent ?? 'No markdown content available',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'View Raw Markdown',
              ),
            ],
          ),
        ),
        if (isPortrait)
             Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Generated: ${DateFormat.yMMMd().format(_currentReport!.createdAt)}',
                  style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey[600]),
                ),
             ),

        Expanded(
          child: ReportView(
            reportData: _currentReport!.structuredData,
            onVerify: () {},
            readonly: true,
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
          Icon(Icons.auto_awesome_outlined, size: 64, color: Colors.indigo.shade100),
          const SizedBox(height: 24),
          Text(
            'No AI report generated for this session',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
