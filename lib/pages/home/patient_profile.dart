import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/models/psychiatric_intake.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/supabase/document_sync_service.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';
import 'package:saber/data/supabase/supabase_intake_service.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/design_system/colors.dart';
import 'package:saber/design_system/radius.dart';
import 'package:saber/design_system/spacing.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/components/loading/skeleton_loader.dart';
import 'package:saber/components/empty_state/empty_state.dart';
import 'package:saber/components/intake_form/psychiatric_intake_form.dart';

/// Patient profile page with demographics, session management, and history
class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key, required this.patientId});

  final String patientId;

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  static final _log = Logger('PatientProfilePage');
  Patient? patient;
  var sessions = <SessionInfo>[];
  var isLoading = true;
  var isSyncing = false;
  String? error;

  // Psychiatric intake state
  PsychiatricIntake? _patientIntake;
  bool _hasCheckedIntake = false;
  String? _doctorName;

  // Selection mode state
  var _isSelectionMode = false;
  final Set<String> _selectedSessionIds = {};

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _fetchDoctorProfile();
  }

  Future<void> _fetchDoctorProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _doctorName = data['full_name'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error fetching doctor profile: $e');
    }
  }

  void _toggleSelection(String sessionId) {
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
        if (_selectedSessionIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  Future<void> _deleteSelectedSessions() async {
    if (patient == null || _selectedSessionIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sessions'),
        content: Text(
          'Are you sure you want to delete ${_selectedSessionIds.length} sessions? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      for (final sessionId in _selectedSessionIds) {
        final sessionPath =
            '${patient!.documentFolderPath(DocumentType.sessionNote)}/$sessionId';
        await FileManager.deleteDirectory(sessionPath);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sessions deleted')));
        setState(() {
          _isSelectionMode = false;
          _selectedSessionIds.clear();
        });
        _loadPatientData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _syncDocuments() async {
    if (patient == null) return;

    setState(() => isSyncing = true);

    try {
      await DocumentSyncService.syncPatientDocuments(
        patient!.id,
        onConflicts: (fileNames) async {
          if (!mounted) return {for (final f in fileNames) f: true};

          // Ask user what to do with missing local files
          final result = await showDialog<Map<String, bool>>(
            context: context,
            barrierDismissible: false,
            builder: (context) => _SyncConflictDialog(fileNames: fileNames),
          );

          // Default to restore all if dialog dismissed
          return result ?? {for (final f in fileNames) f: true};
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents synced successfully')),
        );
        _loadPatientData(); // Reload to show restored files
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
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
      debugPrint(
        'PatientProfile: _loadPatientData started for ${widget.patientId}',
      );
      final loadedPatient = await SupabasePatientService.getPatient(
        widget.patientId,
      );
      debugPrint('PatientProfile: Patient loaded: ${loadedPatient?.fullName}');

      if (loadedPatient == null) {
        setState(() {
          error = 'Patient not found';
          isLoading = false;
        });
        return;
      }

      // Load previous sessions
      final sessionsList = await _loadSessions(loadedPatient);
      debugPrint('PatientProfile: Sessions loaded: ${sessionsList.length}');

      // Load psychiatric intake if not already loaded
      PsychiatricIntake? intake;
      if (!_hasCheckedIntake) {
        intake = await SupabaseIntakeService.getIntake(loadedPatient.id);
        _hasCheckedIntake = true;
      } else {
        intake = _patientIntake;
      }

      setState(() {
        patient = loadedPatient;
        sessions = sessionsList;
        _patientIntake = intake;
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

  /// Show the psychiatric intake form for new patients
  Future<void> _showIntakeForm() async {
    if (patient == null) return;

    final result = await Navigator.of(context).push<PsychiatricIntake>(
      MaterialPageRoute(
        builder: (context) => PsychiatricIntakeForm(
          patient: patient!,
          existingIntake: _patientIntake,
          doctorName: _doctorName,
          readOnly:
              _patientIntake != null, // Read-only if viewing existing intake
          onSave: (intake) async {
            try {
              final savedIntake = await SupabaseIntakeService.upsertIntake(
                intake,
              );
              setState(() {
                _patientIntake = savedIntake;
              });
              if (mounted) {
                Navigator.of(context).pop(savedIntake);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _patientIntake = result;
      });
    }
  }

  Future<void> _confirmAndStartNewSession() async {
    if (patient == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Session'),
        content: Text(
          'Are you sure you want to start a new session for ${patient!.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start Session'),
          ),
        ],
      ),
    );

    // If confirmed, proceed with starting the session
    if (confirmed == true) {
      await _startNewSession();
    }
  }

  Future<void> _startNewSession() async {
    if (patient == null) return;

    try {
      // If this is the first session, show the intake form first
      if (sessions.isEmpty) {
        // Show intake form first for new patients
        await _showIntakeForm();

        // If intake was cancelled and we don't have an intake, don't proceed with session
        if (_patientIntake == null) {
          return;
        }
      }

      // If patient is in Waiting Room, move them to Active automatically
      if (patient!.status == PatientStatus.waiting) {
        await _changePatientStatus(PatientStatus.active);
      }

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

      // Create or find consultation record
      String? consultationId;
      try {
        final user = supabase.auth.currentUser;
        if (user != null) {
          // 1. First check if there's already an active or waiting consultation for this patient and doctor
          final existing = await supabase
              .from('consultations')
              .select('id, status')
              .eq('patient_id', patient!.id)
              .eq('doctor_id', user.id)
              .inFilter('status', ['waiting', 'in_progress'])
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (existing != null) {
            consultationId = existing['id'];
            _log.info('Using existing consultation: $consultationId');

            // If it was waiting, move to in_progress
            if (existing['status'] == 'waiting') {
              await supabase
                  .from('consultations')
                  .update({
                    'status': 'in_progress',
                    'session_start_time': DateTime.now()
                        .toUtc()
                        .toIso8601String(),
                  })
                  .eq('id', consultationId!);
            }
          } else {
            // 2. No existing consultation found, create a new walk-in one
            _log.info('No active consultation found, creating new walk-in...');

            // Get max queue order to maintain consistency
            final maxOrderResponse = await supabase
                .from('consultations')
                .select('queue_order')
                .eq('doctor_id', user.id)
                .or('status.eq.waiting,status.eq.in_progress')
                .order('queue_order', ascending: false)
                .limit(1)
                .maybeSingle();

            final nextQueueOrder =
                (maxOrderResponse?['queue_order'] as int? ?? 0) + 1;

            final response = await supabase
                .from('consultations')
                .insert({
                  'patient_id': patient!.id,
                  'doctor_id': user.id,
                  'status': 'in_progress',
                  'session_start_time': DateTime.now()
                      .toUtc()
                      .toIso8601String(),
                  'scheduled_time': DateTime.now().toUtc().toIso8601String(),
                  'appointment_type': 'walk-in',
                  'queue_order': nextQueueOrder,
                })
                .select()
                .single();
            consultationId = response['id'];
            _log.info('Created new consultation: $consultationId');
          }
        }
      } catch (e) {
        _log.severe('Failed to resolve consultation record', e);
        // We will still proceed to the editor so the doctor doesn't lose their ability to take notes,
        // but now the PrescriptionService has its own safety net to handle a null ID.
      }

      // Navigate to editor with new document
      if (mounted) {
        await context.push(
          RoutePaths.editFilePath(documentPath, consultationId: consultationId),
        );
        if (mounted) {
          _loadPatientData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _changePatientStatus(PatientStatus newStatus) async {
    if (patient == null) return;
    try {
      final updatedPatient = await SupabasePatientService.updatePatientStatus(
        patient!.id,
        newStatus,
      );
      setState(() {
        patient = updatedPatient;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Patient status updated to $_getStatusDisplayName($newStatus)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
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
              content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
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
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedSessionIds.clear();
                  });
                },
              ),
              title: Text('${_selectedSessionIds.length} selected'),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteSelectedSessions,
                  tooltip: 'Delete selected',
                ),
              ],
            )
          : AppBar(
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // Check if there's a returnPath query parameter
                  final uri = GoRouterState.of(context).uri;
                  final returnPath = uri.queryParameters['returnPath'];
                  if (returnPath != null && returnPath.isNotEmpty) {
                    context.go(returnPath);
                  } else {
                    context.go('/home/browse');
                  }
                },
                tooltip: 'Back',
              ),
              title: const Text(
                'Patient Profile',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
                        case 'intake':
                          _showIntakeForm();
                        case 'share':
                          _sharePatientProfile();
                        case 'export':
                          _exportRecords();
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
                      PopupMenuItem(
                        value: 'intake',
                        child: ListTile(
                          leading: Icon(
                            _patientIntake != null
                                ? Icons.assignment_turned_in_outlined
                                : Icons.assignment_outlined,
                          ),
                          title: Text(
                            _patientIntake != null
                                ? 'View/Edit Intake Form'
                                : 'Fill Intake Form',
                          ),
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
          ? _buildLoadingSkeleton()
          : error != null
          ? Center(
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Failed to Load Patient',
                message: error!,
                actionLabel: 'Retry',
                onAction: _loadPatientData,
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
              onPressed: _confirmAndStartNewSession,
              icon: const Icon(Icons.add),
              label: const Text('Start Session'),
            )
          : null,
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Header skeleton
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SkeletonLoader(
                        width: 64,
                        height: 64,
                        shape: BoxShape.circle,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(width: 200, height: 24),
                            SizedBox(height: AppSpacing.xs),
                            SkeletonLoader(width: 150, height: 16),
                          ],
                        ),
                      ),
                      SkeletonLoader(
                        width: 100,
                        height: 32,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  Divider(),
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      SkeletonLoader(
                        width: 80,
                        height: 24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      SkeletonLoader(
                        width: 80,
                        height: 24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      SkeletonLoader(
                        width: 120,
                        height: 24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          // Demographics skeleton
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 180, height: 20),
                  SizedBox(height: AppSpacing.lg),
                  SkeletonLoader(
                    width: double.infinity,
                    height: 60,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonLoader(
                    width: double.infinity,
                    height: 60,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonLoader(
                    width: double.infinity,
                    height: 60,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatientHeader(),
          SizedBox(height: AppSpacing.xl),
          _buildDemographicsCard(),
          SizedBox(height: AppSpacing.lg),
          _buildIntakeStatusCard(),
          SizedBox(height: AppSpacing.xl),
          _buildPreviousSessionsSection(),
          SizedBox(height: AppSpacing.xxl * 2), // Space for FAB
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
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPatientHeader(),
                SizedBox(height: AppSpacing.xl),
                _buildDemographicsCard(),
                SizedBox(height: AppSpacing.lg),
                _buildIntakeStatusCard(),
              ],
            ),
          ),
        ),
        // Right side: Sessions history
        Expanded(
          flex: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviousSessionsSection(),
                  SizedBox(height: AppSpacing.xxl * 2), // Space for FAB
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Hero(
                  tag: 'patient_avatar_${patient!.id}',
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: MedicalColors.getStatusColor(
                      patient!.status.name,
                    ).withOpacity(0.2),
                    child: Text(
                      patient!.fullName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 28,
                        color: MedicalColors.getStatusColor(
                          patient!.status.name,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient!.fullName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Divider(),
            SizedBox(height: AppSpacing.md),
            // Quick info chips
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (patient!.age != null)
                  _buildInfoChip(
                    Icons.cake_outlined,
                    '${patient!.age} years',
                    color: Colors.blue.withOpacity(0.1),
                    contentColor: Colors.blue,
                  ),
                if (patient!.gender != null)
                  _buildInfoChip(
                    Icons.person_outline,
                    patient!.gender!,
                    color: Colors.purple.withOpacity(0.1),
                    contentColor: Colors.purple,
                  ),
                if (patient!.phoneNumber != null)
                  _buildInfoChip(
                    Icons.phone_outlined,
                    patient!.phoneNumber!,
                    color: Colors.green.withOpacity(0.1),
                    contentColor: Colors.green,
                  ),
                if (patient!.lastVisit != null)
                  _buildInfoChip(
                    Icons.event_outlined,
                    'Last: ${DateFormat.yMMMd().format(patient!.lastVisit!)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String label, {
    Color? color,
    Color? contentColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color:
                contentColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: contentColor ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: contentColor != null ? FontWeight.w600 : null,
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
                Expanded(
                  child: Text(
                    'Medical Information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isEmpty
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isEmpty
            ? Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isEmpty
                  ? Theme.of(context).colorScheme.surface
                  : MedicalColors.medicalPrimary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isEmpty
                  ? Theme.of(context).colorScheme.outline
                  : MedicalColors.medicalPrimary,
            ),
          ),
          SizedBox(width: AppSpacing.md),
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
                SizedBox(height: AppSpacing.xxs),
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

  /// Build the psychiatric intake status card
  Widget _buildIntakeStatusCard() {
    final theme = Theme.of(context);
    final hasIntake = _patientIntake != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasIntake
              ? MedicalColors.infoBorder
              : theme.colorScheme.outlineVariant,
        ),
      ),
      color: hasIntake
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
          : null,
      child: InkWell(
        onTap: _showIntakeForm,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasIntake
                      ? MedicalColors.info.withOpacity(0.2)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasIntake
                      ? Icons.assignment_turned_in_outlined
                      : Icons.assignment_outlined,
                  color: hasIntake
                      ? MedicalColors.info
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Psychiatric Intake Form',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasIntake) ...[
                      Text(
                        'Completed on ${_formatDate(_patientIntake!.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: MedicalColors.info,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Show symptom categories summary
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _patientIntake!
                            .getSymptomCategoryCounts()
                            .entries
                            .where((e) => e.value > 0)
                            .take(4)
                            .map(
                              (e) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '${e.key}: ${e.value}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ] else ...[
                      Text(
                        'No intake form on file. Tap to fill out.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: hasIntake
                    ? MedicalColors.info
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  Widget _buildPreviousSessionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clinical Records',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'Detailed logs and AI reports for each session',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        if (sessions.isEmpty)
          EmptyState(
            icon: Icons.history,
            title: 'No Sessions Yet',
            message: 'Start a new session to begin documenting patient care',
            actionLabel: 'Start First Session',
            onAction: _confirmAndStartNewSession,
          )
        else
          _buildSessionsList(),
        SizedBox(height: AppSpacing.xl),
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
        final isSelected = _selectedSessionIds.contains(session.folderName);

        return Dismissible(
          key: Key(session.folderName),
          direction: _isSelectionMode
              ? DismissDirection.none
              : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Session'),
                content: Text(
                  'Are you sure you want to delete Session ${session.sessionNumber}? '
                  'This action cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            // Optimistically remove from list
            final sessionPath =
                '${patient!.documentFolderPath(DocumentType.sessionNote)}/${session.folderName}';

            setState(() {
              sessions.removeAt(index);
            });

            try {
              await FileManager.deleteDirectory(sessionPath);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session deleted')),
                );
              }
            } catch (e) {
              // If delete fails, reload to restore the item
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete session: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
                _loadPatientData();
              }
            }
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            color: isSelected
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3)
                : Theme.of(context).colorScheme.surface,
            child: InkWell(
              onLongPress: () {
                setState(() {
                  _isSelectionMode = true;
                  _toggleSelection(session.folderName);
                });
              },
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(session.folderName);
                } else {
                  _openSession(session);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (value) =>
                              _toggleSelection(session.folderName),
                        )
                      : Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${session.sessionNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                  title: Text(
                    'Session ${session.sessionNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat.yMMMd().format(session.createdDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.description_outlined,
                        size: 12,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${session.fileCount} pages',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: _isSelectionMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View Notes Button
                            FilledButton.tonal(
                              onPressed: () {
                                final sessionPath =
                                    '${patient!.documentFolderPath(DocumentType.sessionNote)}/${session.folderName}';
                                final documentPath =
                                    '$sessionPath/${session.folderName}_notes.sbn';
                                context.push(
                                  RoutePaths.editFilePath(
                                    documentPath,
                                    readOnly: true,
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility, size: 18),
                                  SizedBox(width: 8),
                                  Text('View Notes'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSession(SessionInfo session) {
    if (patient == null) return;

    final route = RoutePaths.sessionViewer
        .replaceAll(':patientId', patient!.id)
        .replaceAll(':sessionNumber', session.sessionNumber.toString());

    context.push(route, extra: {'allSessions': sessions});
  }

  String _getStatusDisplayName(PatientStatus status) {
    switch (status) {
      case PatientStatus.waiting:
        return 'Waiting';
      case PatientStatus.active:
        return 'Active';
      case PatientStatus.discharged:
        return 'Discharged';
      case PatientStatus.archived:
        return 'Archived';
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
  late TextEditingController nameController;
  late TextEditingController ageController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController weightController;

  late TextEditingController allergiesController;
  late TextEditingController addressController;
  String? selectedGender;

  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.patient.fullName);
    ageController = TextEditingController(
      text: widget.patient.age?.toString() ?? '',
    );
    phoneController = TextEditingController(
      text: widget.patient.phoneNumber ?? '',
    );
    emailController = TextEditingController(text: widget.patient.email ?? '');
    weightController = TextEditingController(
      text: widget.patient.weight?.toString() ?? '',
    );

    allergiesController = TextEditingController(
      text: widget.patient.allergies ?? '',
    );
    addressController = TextEditingController(
      text: widget.patient.address ?? '',
    );
    selectedGender = widget.patient.gender;
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    emailController.dispose();
    weightController.dispose();

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
                      // Section 1: Basic Information
                      Text(
                        'Basic Information',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.3),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Full name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: ageController,
                              decoration: InputDecoration(
                                labelText: 'Age',
                                prefixIcon: const Icon(Icons.calendar_today),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.3),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedGender,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: const Icon(Icons.wc),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.3),
                                border: const OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Male',
                                  child: Text('Male'),
                                ),
                                DropdownMenuItem(
                                  value: 'Female',
                                  child: Text('Female'),
                                ),
                                DropdownMenuItem(
                                  value: 'Other',
                                  child: Text('Other'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => selectedGender = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.3),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.3),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section 2: Medical Details
                      Text(
                        'Medical Details',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: weightController,
                              decoration: InputDecoration(
                                labelText: 'Weight (kg)',
                                hintText: 'Enter weight',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(
                                  Icons.monitor_weight_outlined,
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.3),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ],
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
                      if (!formKey.currentState!.validate()) return;

                      final updatedPatient = Patient(
                        id: widget.patient.id,
                        createdAt: widget.patient.createdAt,
                        fullName: nameController.text.trim(),
                        age: int.tryParse(ageController.text.trim()),
                        gender: selectedGender,
                        status: widget.patient.status,
                        lastVisit: widget.patient.lastVisit,
                        doctorId: widget.patient.doctorId,
                        phoneNumber: phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                        email: emailController.text.trim().isEmpty
                            ? null
                            : emailController.text.trim(),
                        medicalHistory: widget.patient.medicalHistory,
                        isActive: widget.patient.isActive,
                        weight: weightController.text.isEmpty
                            ? null
                            : double.tryParse(weightController.text),

                        allergies: allergiesController.text.isEmpty
                            ? null
                            : allergiesController.text,
                        address: addressController.text.isEmpty
                            ? null
                            : addressController.text,
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

class _SyncConflictDialog extends StatefulWidget {
  const _SyncConflictDialog({required this.fileNames});

  final List<String> fileNames;

  @override
  State<_SyncConflictDialog> createState() => _SyncConflictDialogState();
}

class _SyncConflictDialogState extends State<_SyncConflictDialog> {
  // true = restore, false = delete
  final Map<String, bool> _selections = {};

  @override
  void initState() {
    super.initState();
    // Default to restore all
    for (final file in widget.fileNames) {
      _selections[file] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync Conflicts'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The following files exist in cloud but are missing locally. '
              'Select action for each file:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.fileNames.length,
                itemBuilder: (context, index) {
                  final fileName = widget.fileNames[index];
                  final isRestore = _selections[fileName] ?? true;
                  return CheckboxListTile(
                    title: Text(fileName),
                    subtitle: Text(
                      isRestore ? 'Restore to Device' : 'Delete from Cloud',
                      style: TextStyle(
                        color: isRestore
                            ? Colors.green
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                    value: isRestore,
                    onChanged: (value) {
                      setState(() {
                        _selections[fileName] = value ?? true;
                      });
                    },
                    secondary: Icon(
                      isRestore ? Icons.cloud_download : Icons.delete_forever,
                      color: isRestore
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Set all to delete
            setState(() {
              for (final file in widget.fileNames) {
                _selections[file] = false;
              }
            });
          },
          child: const Text('Delete All'),
        ),
        TextButton(
          onPressed: () {
            // Set all to restore
            setState(() {
              for (final file in widget.fileNames) {
                _selections[file] = true;
              }
            });
          },
          child: const Text('Restore All'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selections),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
