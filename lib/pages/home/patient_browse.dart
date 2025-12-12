import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/models/patient.dart';
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
  List<Patient>? patients;
  Patient? selectedPatient;
  List<String>? documents;
  bool isLoading = true;
  String? error;
  StreamSubscription<List<Patient>>? _patientsSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _patientsSubscription?.cancel();
    super.dispose();
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

      final children = await FileManager.getChildrenOfDirectory(path);

      setState(() {
        documents = children?.files ?? [];
        isLoading = false;
      });
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

    if (result == true && fullName != null) {
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

  Widget _buildPatientsList() {
    if (patients == null || patients!.isEmpty) {
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

    return ListView.builder(
      itemCount: patients!.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final patient = patients![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                patient.fullName[0].toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
            trailing: Icon(Icons.chevron_right),
            onTap: () => _openPatient(patient),
          ),
        );
      },
    );
  }

  Widget _buildPatientView() {
    if (selectedPatient == null) {
      return const Center(child: Text('Patient not found'));
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
      appBar: AppBar(
        title: Text(
          selectedPatient != null ? selectedPatient!.fullName : 'Patients',
        ),
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
          : _buildPatientsList(),
      floatingActionButton: selectedPatient == null
          ? FloatingActionButton(
              onPressed: _createNewPatient,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
