import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/models/patient.dart';
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
  _PatientsViewMode _patientsViewMode = _PatientsViewMode.list;

  List<Patient>? patients;
  List<Patient>? filteredPatients;
  Patient? selectedPatient;
  List<String>? documents;
  var isLoading = true;
  String? error;
  StreamSubscription<List<Patient>>? _patientsSubscription;

  // Search state
  final _searchController = TextEditingController();
  var _isSearching = false;

  // Selection state
  var _isSelectionMode = false;
  final Set<String> _selectedPatientIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
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
              p.id.toLowerCase().contains(query);
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
      builder: (context) => AlertDialog(
        title: const Text('Delete Patients'),
        content: Text(
          'Are you sure you want to delete ${_selectedPatientIds.length} patients? '
          'This will permanently delete all their records and documents.',
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
            content: Text('Failed to delete patients: $e'),
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
      isLoading = true;
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
                filteredPatients = patientList;
                _onSearchChanged(); // Re-apply filter
                isLoading = false;
              });
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                error = e.toString();
                isLoading = false;
              });
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
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
        error = e.toString();
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
    final formKey = GlobalKey<FormState>();
    String? fullName;
    int? age;
    String? gender;
    String? phoneNumber;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Patient'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter patient name';
                    }
                    return null;
                  },
                  onSaved: (value) => fullName = value?.trim(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onSaved: (value) =>
                      age = value != null ? int.tryParse(value) : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  onSaved: (value) => gender = value?.trim(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  onSaved: (value) => phoneNumber = value?.trim(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if ((result ?? false) && fullName != null) {
      try {
        setState(() => isLoading = true);
        final patient = await SupabasePatientService.createPatient(
          fullName: fullName!,
          age: age,
          gender: gender,
          phoneNumber: phoneNumber,
        );

        // Create folder structure for new patient
        await _ensurePatientFolderStructure(patient);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Patient "${patient.fullName}" created')),
          );
        }

        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create patient: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        setState(() => isLoading = false);
      }
    }
  }

  void _openPatient(Patient patient) {
    context.go('/home/patients/${patient.id}');
  }

  void _openDocumentType(Patient patient, DocumentType type) {
    context.go('/home/patients/${patient.id}/${type.folderName}');
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

        return Dismissible(
          key: Key(patient.id),
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
                title: const Text('Delete Patient'),
                content: Text(
                  'Are you sure you want to delete ${patient.fullName}? '
                  'This will permanently delete all their records and documents.',
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
            // Dismissible requires the item to be removed from the tree immediately.
            // Remove from local lists first, then perform async deletion.
            final removedPatient = patient;
            final removedPatientsIndex =
                patients?.indexWhere((p) => p.id == removedPatient.id) ?? -1;
            final removedFilteredIndex =
                filteredPatients?.indexWhere(
                  (p) => p.id == removedPatient.id,
                ) ??
                -1;

            setState(() {
              patients?.removeWhere((p) => p.id == removedPatient.id);
              filteredPatients?.removeWhere((p) => p.id == removedPatient.id);
              _selectedPatientIds.remove(removedPatient.id);
              if (_selectedPatientIds.isEmpty) _isSelectionMode = false;
            });

            try {
              await SupabasePatientService.deletePatient(removedPatient.id);
            } catch (e) {
              // Restore the patient in the UI if server deletion failed.
              if (mounted) {
                setState(() {
                  if (patients != null && removedPatientsIndex >= 0) {
                    final safeIndex = removedPatientsIndex.clamp(
                      0,
                      patients!.length,
                    );
                    patients!.insert(safeIndex, removedPatient);
                  } else {
                    patients ??= <Patient>[];
                    patients!.insert(0, removedPatient);
                  }

                  if (filteredPatients != null && removedFilteredIndex >= 0) {
                    final safeIndex = removedFilteredIndex.clamp(
                      0,
                      filteredPatients!.length,
                    );
                    filteredPatients!.insert(safeIndex, removedPatient);
                  }
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete patient: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
              return;
            }

            try {
              await FileManager.deleteDirectory(removedPatient.localFolderPath);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Deleted patient, but failed to delete local files: $e',
                    ),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${removedPatient.fullName} deleted')),
              );
            }
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isSelected
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3)
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
                    : CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          patient.fullName[0].toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                title: Text(patient.fullName),
                subtitle: Text(
                  [
                    if (patient.age != null) '${patient.age} years',
                    if (patient.gender != null) patient.gender!,
                    patient.status.value.replaceAll('_', ' '),
                  ].join(' • '),
                ),
                trailing: _isSelectionMode
                    ? null
                    : const Icon(Icons.chevron_right),
              ),
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
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
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
                          CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Text(
                              patient.fullName[0].toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                      Text(
                        [
                          if (patient.age != null) '${patient.age} years',
                          if (patient.gender != null) patient.gender!,
                          patient.status.value.replaceAll('_', ' '),
                        ].join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
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
              DataColumn(label: Text('Status')),
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
                      DataCell(Text(patient.gender ?? '—')),
                      DataCell(Text(patient.status.value.replaceAll('_', ' '))),
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
                Text(
                  [
                    if (selectedPatient!.age != null)
                      '${selectedPatient!.age} years',
                    if (selectedPatient!.gender != null)
                      selectedPatient!.gender!,
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
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
    final relativePath = '${selectedPatient!.documentFolderPath(docType)}/$fileName';
    
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to read file: $e')),
          );
        }
      }
    } else {
      // Open other files (Saber notes) in the editor
      context.push(RoutePaths.editFilePath(relativePath));
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
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              ),
              title: Text('${_selectedPatientIds.length} selected'),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteSelectedPatients,
                  tooltip: 'Delete selected',
                ),
              ],
            )
          : AppBar(
              leading: selectedPatient != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go('/home/patients/${selectedPatient!.id}'),
                    )
                  : null,
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search patients...',
                        border: InputBorder.none,
                      ),
                    )
                  : Text(
                      selectedPatient != null
                          ? selectedPatient!.fullName
                          : 'Patients',
                    ),
              actions: [
                if (selectedPatient == null)
                  PopupMenuButton<_PatientsViewMode>(
                    tooltip: 'View mode',
                    initialValue: _patientsViewMode,
                    onSelected: (mode) {
                      setState(() {
                        _patientsViewMode = mode;
                      });
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _PatientsViewMode.list,
                        child: Text('List'),
                      ),
                      PopupMenuItem(
                        value: _PatientsViewMode.grid,
                        child: Text('Grid'),
                      ),
                      PopupMenuItem(
                        value: _PatientsViewMode.table,
                        child: Text('Table'),
                      ),
                    ],
                    icon: Icon(switch (_patientsViewMode) {
                      _PatientsViewMode.list => Icons.view_list,
                      _PatientsViewMode.grid => Icons.grid_view,
                      _PatientsViewMode.table => Icons.table_rows,
                    }),
                  ),
                if (selectedPatient == null)
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close : Icons.search),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                        }
                      });
                    },
                  ),
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
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : selectedPatient != null
          ? _buildPatientView()
          : _buildPatientsView(),
      floatingActionButton: selectedPatient == null
          ? FloatingActionButton(
              onPressed: _createNewPatient,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

enum _PatientsViewMode { list, grid, table }
