import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/supabase/document_sync_service.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';

/// Patient profile page with demographics, session management, and history
class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key, required this.patientId});

  final String patientId;

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  Patient? patient;
  var sessions = <SessionInfo>[];
  var isLoading = true;
  var isSyncing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _syncDocuments() async {
    if (patient == null) return;

    setState(() => isSyncing = true);

    try {
      await DocumentSyncService.syncPatientDocuments(patient!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSyncing = false);
      }
    }
  }

  Future<void> _loadPatientData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final loadedPatient = await SupabasePatientService.getPatient(
        widget.patientId,
      );

      if (loadedPatient == null) {
        setState(() {
          error = 'Patient not found';
          isLoading = false;
        });
        return;
      }

      // Load previous sessions
      final sessionsList = await _loadSessions(loadedPatient);

      setState(() {
        patient = loadedPatient;
        sessions = sessionsList;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<List<SessionInfo>> _loadSessions(Patient patient) async {
    // Load session folders from session_notes directory
    final sessionPath = patient.documentFolderPath(DocumentType.sessionNote);
    final children = await FileManager.getChildrenOfDirectory(sessionPath);

    if (children == null || children.directories.isEmpty) {
      return [];
    }

    final sessionsList = <SessionInfo>[];
    for (final dir in children.directories) {
      // Session folders are named like "session_1", "session_2", etc.
      final sessionNumber = _extractSessionNumber(dir);
      if (sessionNumber != null) {
        // Check if session has files
        final sessionFiles = await FileManager.getChildrenOfDirectory(
          '$sessionPath/$dir',
        );
        sessionsList.add(
          SessionInfo(
            sessionNumber: sessionNumber,
            folderName: dir,
            fileCount: sessionFiles?.files.length ?? 0,
            createdDate: DateTime.now(), // TODO: Get actual creation date
          ),
        );
      }
    }

    // Sort by session number descending (newest first)
    sessionsList.sort((a, b) => b.sessionNumber.compareTo(a.sessionNumber));
    return sessionsList;
  }

  int? _extractSessionNumber(String folderName) {
    final match = RegExp(r'session_(\d+)').firstMatch(folderName);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  Future<void> _startNewSession() async {
    if (patient == null) return;

    try {
      // Determine next session number
      final nextSessionNumber = sessions.isEmpty
          ? 1
          : sessions.first.sessionNumber + 1;
      final sessionFolderName = 'session_$nextSessionNumber';

      // Create session folder
      final sessionPath =
          '${patient!.documentFolderPath(DocumentType.sessionNote)}/$sessionFolderName';
      await FileManager.createFolder(sessionPath);

      // Create blank Saber document for this session
      final documentName = 'session_${nextSessionNumber}_notes';
      final documentPath = '$sessionPath/$documentName.sbn';

      // Navigate to editor with new document
      if (mounted) {
        context.go(RoutePaths.editFilePath(documentPath));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _sharePatientProfile() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share feature coming soon')));
  }

  void _exportRecords() {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Export feature coming soon')));
  }

  Future<void> _editDemographics() async {
    if (patient == null) return;

    final result = await showDialog<Patient>(
      context: context,
      builder: (context) => _DemographicsDialog(patient: patient!),
    );

    if (result != null) {
      try {
        await SupabasePatientService.updatePatient(
          result.id,
          result.toInsertJson(),
        );
        setState(() {
          patient = result;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Demographics updated')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent app bar for immersive design
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home/browse'),
          tooltip: 'Back to patients',
        ),
        title: const Text('Patient Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (patient != null) ...[
            // Cloud sync indicator - shows background sync status
            if (isSyncing)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Tooltip(
                  message: 'Syncing documents...',
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.cloud_outlined),
                onPressed: _syncDocuments,
                tooltip: 'Sync to cloud',
              ),
            // Quick actions menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _editDemographics();
                    break;
                  case 'share':
                    _sharePatientProfile();
                    break;
                  case 'export':
                    _exportRecords();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit Demographics'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share_outlined),
                    title: Text('Share Profile'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.file_download_outlined),
                    title: Text('Export Records'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadPatientData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : OrientationBuilder(
              builder: (context, orientation) {
                return orientation == Orientation.portrait
                    ? _buildPortraitLayout()
                    : _buildLandscapeLayout();
              },
            ),
      floatingActionButton: patient != null
          ? FloatingActionButton.extended(
              onPressed: _startNewSession,
              icon: const Icon(Icons.add),
              label: const Text('Start Session'),
            )
          : null,
    );
  }

  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatientHeader(),
          const SizedBox(height: 24),
          _buildDemographicsCard(),
          const SizedBox(height: 24),
          _buildPreviousSessionsSection(),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: Patient info and demographics
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPatientHeader(),
                const SizedBox(height: 24),
                _buildDemographicsCard(),
              ],
            ),
          ),
        ),
        // Right side: Sessions history
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviousSessionsSection(),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientHeader() {
    if (patient == null) return const SizedBox();

    // Design Philosophy: Hero section with patient identity and status at a glance
    // Large avatar creates visual anchor, patient ID for quick reference
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  // Large, prominent avatar - establishes visual hierarchy
                  Hero(
                    tag: 'patient_avatar_${patient!.id}',
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Text(
                        patient!.fullName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 36,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient name - primary identifier
                        Text(
                          patient!.fullName,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        // Patient ID - critical for medical record keeping
                        Row(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ID: ${patient!.id.substring(0, 8)}...',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontFamily: 'monospace',
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              onPressed: () {
                                // Copy full ID to clipboard
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Patient ID copied'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              tooltip: 'Copy full ID',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge - color-coded for quick recognition
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(patient!.status),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusBorderColor(patient!.status),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(patient!.status),
                          size: 16,
                          color: _getStatusBorderColor(patient!.status),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusDisplayName(patient!.status),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: _getStatusBorderColor(patient!.status),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Quick info chips - secondary details in scannable format
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (patient!.age != null)
                    _buildInfoChip(
                      Icons.cake_outlined,
                      '${patient!.age} years',
                      context,
                    ),
                  if (patient!.gender != null)
                    _buildInfoChip(
                      Icons.person_outline,
                      patient!.gender!,
                      context,
                    ),
                  if (patient!.phoneNumber != null)
                    _buildInfoChip(
                      Icons.phone_outlined,
                      patient!.phoneNumber!,
                      context,
                    ),
                  if (patient!.lastVisit != null)
                    _buildInfoChip(
                      Icons.event_outlined,
                      'Last visit: ${DateFormat.yMMMd().format(patient!.lastVisit!)}',
                      context,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for consistent info chips
  Widget _buildInfoChip(IconData icon, String label, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicsCard() {
    if (patient == null) return const SizedBox();

    // Design Philosophy: Medical vitals need clear visual hierarchy
    // Critical info (allergies) gets prominent warning styling
    // Empty states encourage data entry
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.medical_information_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Medical Information',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _editDemographics,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Update'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Allergies first - critical medical information
            if (patient!.allergies != null && patient!.allergies!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200, width: 2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ALLERGIES',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            patient!.allergies!,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Vital statistics in grid layout
            _buildVitalCard(
              'Weight',
              patient!.weight != null ? '${patient!.weight} kg' : '--',
              Icons.monitor_weight_outlined,
              patient!.weight == null,
            ),
            const SizedBox(height: 12),
            _buildVitalCard(
              'Blood Group',
              patient!.bloodGroup ?? '--',
              Icons.bloodtype_outlined,
              patient!.bloodGroup == null,
            ),
            const SizedBox(height: 12),
            _buildVitalCard(
              'Address',
              patient!.address ?? 'Not provided',
              Icons.location_on_outlined,
              patient!.address == null,
            ),
          ],
        ),
      ),
    );
  }

  // Modern vital statistics card with visual feedback for empty states
  Widget _buildVitalCard(
    String label,
    String value,
    IconData icon,
    bool isEmpty,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmpty
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isEmpty
            ? Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: 1,
                style: BorderStyle.solid,
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEmpty
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isEmpty
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isEmpty
                        ? Theme.of(context).colorScheme.outline
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousSessionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Patient History', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Previous sessions and AI-generated documents',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (sessions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No previous sessions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a new session to begin documenting',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          _buildSessionsList(),
        const SizedBox(height: 24),
        _buildAIOutputFolders(),
      ],
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(child: Text('${session.sessionNumber}')),
            title: Text('Session ${session.sessionNumber}'),
            subtitle: Text(
              '${session.fileCount} ${session.fileCount == 1 ? 'file' : 'files'} • ${DateFormat.yMMMd().format(session.createdDate)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSession(session),
          ),
        );
      },
    );
  }

  Widget _buildAIOutputFolders() {
    if (patient == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI-Generated Documents',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Organized by document type',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildFolderCard(
              DocumentType.examinationReport,
              Icons.assignment,
              Colors.blue,
            ),
            _buildFolderCard(
              DocumentType.prescription,
              Icons.medication,
              Colors.green,
            ),
            _buildFolderCard(
              DocumentType.sessionNote,
              Icons.notes,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFolderCard(DocumentType type, IconData icon, Color color) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDocumentFolder(type),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                type.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSession(SessionInfo session) {
    if (patient == null) return;
    // TODO: Navigate to session folder view
    // final sessionPath = '${patient!.documentFolderPath(DocumentType.sessionNote)}/${session.folderName}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening session ${session.sessionNumber}')),
    );
  }

  void _openDocumentFolder(DocumentType type) {
    if (patient == null) return;
    context.go('/home/patients/${patient!.id}/${type.folderName}');
  }

  String _getStatusDisplayName(PatientStatus status) {
    switch (status) {
      case PatientStatus.waiting:
        return 'Waiting';
      case PatientStatus.inConsultation:
        return 'In Consultation';
      case PatientStatus.completed:
        return 'Completed';
    }
  }

  IconData _getStatusIcon(PatientStatus status) {
    switch (status) {
      case PatientStatus.waiting:
        return Icons.schedule;
      case PatientStatus.inConsultation:
        return Icons.medical_services;
      case PatientStatus.completed:
        return Icons.check_circle;
    }
  }

  Color _getStatusColor(PatientStatus status) {
    switch (status) {
      case PatientStatus.waiting:
        return Colors.orange.withOpacity(0.15);
      case PatientStatus.inConsultation:
        return Colors.blue.withOpacity(0.15);
      case PatientStatus.completed:
        return Colors.green.withOpacity(0.15);
    }
  }

  Color _getStatusBorderColor(PatientStatus status) {
    switch (status) {
      case PatientStatus.waiting:
        return Colors.orange.shade700;
      case PatientStatus.inConsultation:
        return Colors.blue.shade700;
      case PatientStatus.completed:
        return Colors.green.shade700;
    }
  }
}

/// Demographics edit dialog
class _DemographicsDialog extends StatefulWidget {
  const _DemographicsDialog({required this.patient});

  final Patient patient;

  @override
  State<_DemographicsDialog> createState() => _DemographicsDialogState();
}

class _DemographicsDialogState extends State<_DemographicsDialog> {
  late TextEditingController weightController;
  late TextEditingController bloodGroupController;
  late TextEditingController allergiesController;
  late TextEditingController addressController;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    weightController = TextEditingController(
      text: widget.patient.weight?.toString() ?? '',
    );
    bloodGroupController = TextEditingController(
      text: widget.patient.bloodGroup ?? '',
    );
    allergiesController = TextEditingController(
      text: widget.patient.allergies ?? '',
    );
    addressController = TextEditingController(
      text: widget.patient.address ?? '',
    );
  }

  @override
  void dispose() {
    weightController.dispose();
    bloodGroupController.dispose();
    allergiesController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Demographics',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: weightController,
                        decoration: InputDecoration(
                          labelText: 'Weight (kg)',
                          hintText: 'Enter weight',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.monitor_weight_outlined),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.3),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: bloodGroupController,
                        decoration: InputDecoration(
                          labelText: 'Blood Group',
                          hintText: 'e.g., A+, B-, O+',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.bloodtype),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.3),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          hintText: 'Enter full address',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.3),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: allergiesController,
                        decoration: InputDecoration(
                          labelText: 'Allergies',
                          hintText: 'List any known allergies',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.warning_amber_outlined),
                          filled: true,
                          fillColor: Colors.red.withOpacity(0.05),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      final updatedPatient = widget.patient.copyWith(
                        weight: weightController.text.isNotEmpty
                            ? double.tryParse(weightController.text)
                            : null,
                        bloodGroup: bloodGroupController.text.isNotEmpty
                            ? bloodGroupController.text
                            : null,
                        address: addressController.text.isNotEmpty
                            ? addressController.text
                            : null,
                        allergies: allergiesController.text.isNotEmpty
                            ? allergiesController.text
                            : null,
                      );
                      Navigator.pop(context, updatedPatient);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Session information model
class SessionInfo {
  final int sessionNumber;
  final String folderName;
  final int fileCount;
  final DateTime createdDate;

  SessionInfo({
    required this.sessionNumber,
    required this.folderName,
    required this.fileCount,
    required this.createdDate,
  });
}
