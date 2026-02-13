import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:saber/components/intake_form/patient_registration_wizard.dart';
import 'package:saber/components/misc/saber_avatar.dart';
import 'package:saber/components/navbar/responsive_navbar.dart';
import 'package:saber/components/theming/premium_confirmation_dialog.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';

/// Patient-centric browse page showing patients and their documents
class PatientBrowsePage extends StatefulWidget {
  const PatientBrowsePage({super.key, this.patientId, this.documentType});

  final String? patientId;
  final String? documentType;

  @override
  State<PatientBrowsePage> createState() => _PatientBrowsePageState();
}

class _PatientBrowsePageState extends State<PatientBrowsePage> {
  // Patient list view mode (only applies when viewing the patients list)
  _PatientsViewMode _patientsViewMode = _PatientsViewMode.grid;

  List<Patient>? patients;
  List<Patient>? filteredPatients;
  Patient? selectedPatient;
  List<String>? documents;
  var isLoading = true;
  String? error;
  StreamSubscription<List<Patient>>? _patientsSubscription;

  // Search state
  final _searchController = TextEditingController();
  var _retryCount = 0;

  // Selection state
  var _isSelectionMode = false;
  final Set<String> _selectedPatientIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
    stows.isOnline.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (stows.isOnline.value && mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    stows.isOnline.removeListener(_onConnectivityChanged);
    _patientsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (patients == null) return;
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredPatients = patients;
      } else {
        filteredPatients = patients!.where((p) {
          return p.fullName.toLowerCase().contains(query) ||
              (p.registrationNumber?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPatientIds.clear();
      }
    });
  }

  void _toggleSelection(String patientId) {
    setState(() {
      if (_selectedPatientIds.contains(patientId)) {
        _selectedPatientIds.remove(patientId);
        if (_selectedPatientIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPatientIds.add(patientId);
      }
    });
  }

  Future<void> _deleteSelectedPatients() async {
    if (_selectedPatientIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => PremiumConfirmationDialog(
        title: 'Delete Patients',
        content:
            'Are you sure you want to delete ${_selectedPatientIds.length} patients? '
            'This will permanently delete all their records and documents.',
        confirmLabel: 'Delete',
        isDestructive: true,
        icon: Icons.delete_forever_rounded,
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => isLoading = true);

      // Delete from Supabase first; only delete local data after DB delete succeeds.
      for (final id in _selectedPatientIds) {
        final patient = patients?.firstWhere((p) => p.id == id);
        await SupabasePatientService.deletePatient(id);
        if (patient != null) {
          await FileManager.deleteDirectory(patient.localFolderPath);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patients deleted successfully')),
        );
        setState(() {
          _isSelectionMode = false;
          _selectedPatientIds.clear();
        });
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
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      if (patients == null) isLoading = true;
      error = null;
    });

    try {
      if (widget.patientId != null) {
        // Load specific patient and their documents
        final patient = await SupabasePatientService.getPatient(
          widget.patientId!,
        );
        if (patient != null) {
          await _loadPatientDocuments(patient);
        } else {
          setState(() {
            error = 'Patient not found';
            isLoading = false;
          });
        }
      } else {
        // Load all patients
        _patientsSubscription?.cancel();
        _patientsSubscription = SupabasePatientService.watchPatients().listen(
          (patientList) {
            if (mounted) {
              setState(() {
                patients = patientList;
                _retryCount = 0; // Reset retry count on success
                patients?.sort(
                  (a, b) => a.fullName.toLowerCase().compareTo(
                    b.fullName.toLowerCase(),
                  ),
                );
                filteredPatients = patients;
                _onSearchChanged(); // Re-apply filter
                isLoading = false;
              });
            }
          },
          onError: (e) {
            if (mounted) {
              final errorStr = e.toString().toLowerCase();
              if (errorStr.contains('timedout') && _retryCount < 3) {
                _retryCount++;
                debugPrint(
                  'PatientBrowse: Subscription timed out, retrying ($_retryCount/3)...',
                );
                Future.delayed(
                  Duration(seconds: 2 * _retryCount),
                  () => _loadData(),
                );
                return;
              }

              setState(() {
                error = ErrorHandler.getFriendlyErrorMessage(e);
                isLoading = false;
              });
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = ErrorHandler.getFriendlyErrorMessage(e);
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPatientDocuments(Patient patient) async {
    setState(() {
      selectedPatient = patient;
      isLoading = true;
    });

    try {
      // Ensure patient folder exists
      await _ensurePatientFolderStructure(patient);

      // Load documents for specific type or all
      final DocumentType? docType = widget.documentType != null
          ? DocumentType.values.firstWhere(
              (t) => t.folderName == widget.documentType,
            )
          : null;

      final path = docType != null
          ? patient.documentFolderPath(docType)
          : patient.localFolderPath;

      // Use direct directory listing to include all file types (md, pdf, etc.)
      // FileManager.getChildrenOfDirectory filters for .sbn files by default
      final fullPath = '${FileManager.documentsDirectory}$path';
      final dir = Directory(fullPath);

      if (await dir.exists()) {
        final entities = await dir.list().toList();
        final fileNames = entities
            .whereType<File>()
            .map((e) => p.basename(e.path))
            .where((name) => !name.startsWith('.')) // Filter hidden files
            .toList();

        setState(() {
          documents = fileNames;
          isLoading = false;
        });
      } else {
        setState(() {
          documents = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = ErrorHandler.getFriendlyErrorMessage(e);
        isLoading = false;
      });
    }
  }

  Future<void> _ensurePatientFolderStructure(Patient patient) async {
    // Create patient root folder
    await FileManager.createFolder(patient.localFolderPath);

    // Create document type folders
    for (final docType in DocumentType.values) {
      await FileManager.createFolder(patient.documentFolderPath(docType));
    }
  }

  Future<void> _createNewPatient() async {
    final patient = await showDialog<Patient>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DoctorPatientRegistrationWizard(),
    );

    if (patient != null && mounted) {
      // Create folder structure for new patient locally
      await _ensurePatientFolderStructure(patient);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Patient "${patient.fullName}" registered')),
        );

        // Navigate to the new patient's profile directly
        _openPatient(patient, autoStartSession: true);
      }
    }
  }

  void _openPatient(Patient patient, {bool autoStartSession = false}) {
    if (context.mounted) {
      var path = '/home/patients/${patient.id}';
      if (autoStartSession) {
        path += '?autoStartSession=true';
      }
      context.go(path);
    }
  }

  void _openDocumentType(Patient patient, DocumentType type) {
    if (context.mounted) {
      context.go('/home/patients/${patient.id}/${type.folderName}');
    }
  }

  Widget? _buildPatientsEmptyState(List<Patient>? displayList) {
    if (displayList != null && displayList.isNotEmpty) return null;

    if (_searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No patients found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No patients yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first patient',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsView() {
    final displayList = filteredPatients;
    final emptyState = _buildPatientsEmptyState(displayList);
    if (emptyState != null) return emptyState;

    return switch (_patientsViewMode) {
      _PatientsViewMode.list => _buildPatientsListView(displayList!),
      _PatientsViewMode.grid => _buildPatientsGridView(displayList!),
      _PatientsViewMode.table => _buildPatientsTableView(displayList!),
    };
  }

  Widget _buildPatientsListView(List<Patient> displayList) {
    return ListView.builder(
      itemCount: displayList.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final patient = displayList[index];
        final isSelected = _selectedPatientIds.contains(patient.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          child: InkWell(
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                _toggleSelection(patient.id);
              });
            },
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(patient.id);
              } else {
                _openPatient(patient);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: _isSelectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (value) => _toggleSelection(patient.id),
                    )
                  : SaberAvatar(
                      url: patient.avatarUrl,
                      radius: 20,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      fallbackIcon: Icons.person_outline,
                    ),
              title: Text(patient.fullName),
              subtitle: _buildPatientMetadata(patient: patient),
              trailing: _isSelectionMode
                  ? null
                  : const Icon(Icons.chevron_right),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPatientsGridView(List<Patient> displayList) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 900
        ? 4
        : width >= 700
        ? 3
        : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final patient = displayList[index];
        final isSelected = _selectedPatientIds.contains(patient.id);

        return Card(
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          child: InkWell(
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                _toggleSelection(patient.id);
              });
            },
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(patient.id);
              } else {
                _openPatient(patient);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SaberAvatar(
                            url: patient.avatarUrl,
                            radius: 20,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            fallbackIcon: Icons.person_outline,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              patient.fullName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPatientMetadata(patient: patient),
                    ],
                  ),
                  if (_isSelectionMode)
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(patient.id),
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

  Widget _buildPatientsTableView(List<Patient> displayList) {
    final minWidth = MediaQuery.sizeOf(context).width - 32;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: SingleChildScrollView(
          child: DataTable(
            // We provide our own checkbox column, so disable the built-in one.
            showCheckboxColumn: false,
            headingRowColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            columnSpacing: 24,
            horizontalMargin: 12,
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 56,
            columns: const [
              DataColumn(label: Text('')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Age')),
              DataColumn(label: Text('Gender')),
            ],
            rows: displayList
                .map((patient) {
                  final isSelected = _selectedPatientIds.contains(patient.id);

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) {
                      if (_isSelectionMode) {
                        _toggleSelection(patient.id);
                      } else {
                        _openPatient(patient);
                      }
                    },
                    cells: [
                      DataCell(
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) {
                            setState(() {
                              _isSelectionMode = true;
                            });
                            _toggleSelection(patient.id);
                          },
                        ),
                      ),
                      DataCell(Text(patient.fullName)),
                      DataCell(Text(patient.age?.toString() ?? '—')),
                      DataCell(
                        patient.gender != null
                            ? _buildGenderTag(patient.gender!)
                            : const Text('—'),
                      ),
                    ],
                  );
                })
                .toList(growable: false),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientView() {
    if (selectedPatient == null) {
      return const Center(child: Text('Patient not found'));
    }

    if (widget.documentType != null) {
      return _buildDocumentsList();
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedPatient!.fullName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                _buildPatientMetadata(patient: selectedPatient, isLarge: true),
                const SizedBox(height: 16),
                Text(
                  'Document Types',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final docType = DocumentType.values[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(_getDocumentTypeIcon(docType)),
                  title: Text(docType.displayName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDocumentType(selectedPatient!, docType),
                ),
              );
            }, childCount: DocumentType.values.length),
          ),
        ),
      ],
    );
  }

  void _openDocument(String fileName) async {
    if (selectedPatient == null || widget.documentType == null) return;

    final docType = DocumentType.values.firstWhere(
      (t) => t.folderName == widget.documentType,
    );
    final relativePath =
        '${selectedPatient!.documentFolderPath(docType)}/$fileName';

    if (fileName.toLowerCase().endsWith('.md')) {
      // Show Markdown files in a dialog
      try {
        final fullPath = '${FileManager.documentsDirectory}$relativePath';
        final content = await File(fullPath).readAsString();

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              child: Column(
                children: [
                  AppBar(
                    title: Text(fileName),
                    leading: const CloseButton(),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                  ),
                  Expanded(
                    child: Markdown(
                      data: content,
                      selectable: true,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to read file: $e')));
        }
      }
    } else {
      // Open other files (Saber notes) in the editor
      if (context.mounted) {
        context.push(RoutePaths.editFilePath(relativePath));
      }
    }
  }

  Widget _buildDocumentsList() {
    if (documents == null || documents!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No documents found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: documents!.length,
      itemBuilder: (context, index) {
        final fileName = documents![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.description),
            title: Text(fileName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDocument(fileName),
          ),
        );
      },
    );
  }

  Widget _buildGenderTag(String gender, {bool isLarge = false}) {
    final lowerGender = gender.toLowerCase().trim();
    Color backgroundColor;
    Color textColor;

    if (lowerGender == 'male' || lowerGender == 'm') {
      backgroundColor = Colors.blue.withValues(alpha: 0.1);
      textColor = Colors.blue.shade700;
    } else if (lowerGender == 'female' || lowerGender == 'f') {
      backgroundColor = Colors.pink.withValues(alpha: 0.1);
      textColor = Colors.pink.shade700;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        gender,
        style:
            (isLarge
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.bodySmall)
                ?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPatientMetadata({Patient? patient, bool isLarge = false}) {
    if (patient == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (patient.age != null) ...[
          Text(
            '${patient.age} years',
            style: isLarge
                ? Theme.of(context).textTheme.bodyLarge
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            '•',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (patient.gender != null)
          _buildGenderTag(patient.gender!, isLarge: isLarge),
      ],
    );
  }

  IconData _getDocumentTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.examinationReport:
        return Icons.assignment;
      case DocumentType.prescription:
        return Icons.medication;
      case DocumentType.sessionNote:
        return Icons.notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_isSelectionMode)
              _buildSelectionHeader()
            else
              _buildCustomHeader(),
            Expanded(
              child: isLoading
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
                            onPressed: _loadData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : selectedPatient != null
                  ? _buildPatientView()
                  : _buildPatientsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _toggleSelectionMode,
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedPatientIds.length} selected',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteSelectedPatients,
            tooltip: 'Delete selected',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader() {
    final theme = Theme.of(context);
    final isDesktop = ResponsiveNavbar.isLargeScreen;

    return Padding(
      padding: EdgeInsets.only(
        top: isDesktop ? 24 : 12,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (selectedPatient != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () {
                    if (context.mounted) {
                      context.go('/home/patients');
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (selectedPatient != null) const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPatient != null
                        ? selectedPatient!.fullName
                        : 'Patients',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (selectedPatient == null && patients != null)
                    Text(
                      '${patients!.length} total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (selectedPatient == null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(switch (_patientsViewMode) {
                        _PatientsViewMode.list => Icons.view_list,
                        _PatientsViewMode.grid => Icons.grid_view,
                        _PatientsViewMode.table => Icons.table_rows,
                      }),
                      onPressed: () {
                        // Toggle through modes
                        setState(() {
                          _patientsViewMode =
                              _PatientsViewMode
                                  .values[(_patientsViewMode.index + 1) %
                                  _PatientsViewMode.values.length];
                        });
                      },
                      tooltip: 'Toggle view mode',
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: _createNewPatient,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
            ],
          ),
          if (selectedPatient == null) ...[
            const SizedBox(height: 16),
            _buildSearchBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search patients by name or Reg No...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

enum _PatientsViewMode { list, grid, table }
