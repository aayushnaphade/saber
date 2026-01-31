import 'package:flutter/material.dart';
import 'package:saber/i18n/strings.g.dart';

class ReportView extends StatefulWidget {
  const ReportView({
    super.key,
    required this.reportData,
    required this.onVerify,
  });

  final Map<String, dynamic> reportData;
  final VoidCallback onVerify;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  late TextEditingController _currentSymptomsController;
  late TextEditingController _premorbidPersonalityController;
  late TextEditingController _pastHistoryController;
  late TextEditingController _familyHistoryController;
  late TextEditingController _diagnosisController;
  
  // MSE Controllers
  final Map<String, TextEditingController> _mseControllers = {};

  // Medications
  final List<Map<String, String>> _medications = [];

  @override
  void initState() {
    super.initState();
    _currentSymptomsController = TextEditingController(text: widget.reportData['current_symptoms'] ?? '');
    _premorbidPersonalityController = TextEditingController(text: widget.reportData['premorbid_personality'] ?? '');
    _pastHistoryController = TextEditingController(text: widget.reportData['past_history'] ?? '');
    _familyHistoryController = TextEditingController(text: widget.reportData['family_history'] ?? '');
    _diagnosisController = TextEditingController(text: widget.reportData['provided_diagnosis'] ?? '');

    final mse = widget.reportData['mental_status_examination'];
    if (mse is Map) {
      mse.forEach((key, value) {
        _mseControllers[key.toString()] = TextEditingController(text: value?.toString() ?? '');
      });
    } else if (mse is String) {
      _mseControllers['MSE'] = TextEditingController(text: mse);
    }

    // Initialize Medications
    final meds = widget.reportData['medications'];
    if (meds is List) {
      for (final m in meds) {
        if (m is Map) {
          _medications.add({
            'name': m['name']?.toString() ?? '',
            'frequency': m['frequency']?.toString() ?? '',
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _currentSymptomsController.dispose();
    _premorbidPersonalityController.dispose();
    _pastHistoryController.dispose();
    _familyHistoryController.dispose();
    _diagnosisController.dispose();
    for (final controller in _mseControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Assessment Report'),
        actions: [
          TextButton.icon(
            onPressed: () {
                // Update reportData with current values before verifying
                widget.reportData['current_symptoms'] = _currentSymptomsController.text;
                widget.reportData['premorbid_personality'] = _premorbidPersonalityController.text;
                widget.reportData['past_history'] = _pastHistoryController.text;
                widget.reportData['family_history'] = _familyHistoryController.text;
                widget.reportData['provided_diagnosis'] = _diagnosisController.text;
                widget.reportData['mental_status_examination'] = Map.fromEntries(
                  _mseControllers.entries.map((e) => MapEntry(e.key, e.value.text)),
                );
                widget.reportData['medications'] = _medications;
                widget.onVerify();
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Verify & Save'),
          ),
        ],
      ),
      body: RepaintBoundary(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ReportSection(
              title: 'Current Symptoms (HPI)',
              controller: _currentSymptomsController,
            ),
            _ReportSection(
              title: 'Premorbid Personality',
              controller: _premorbidPersonalityController,
            ),
            _ReportSection(
              title: 'Past History',
              controller: _pastHistoryController,
            ),
            _ReportSection(
              title: 'Family History',
              controller: _familyHistoryController,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Mental Status Examination',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: _mseControllers.entries.map((entry) {
                    return _ReportSection(
                      title: entry.key.replaceAll('_', ' ').toUpperCase(),
                      controller: entry.value,
                      maxLines: 1,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ReportSection(
              title: 'Provided Diagnosis',
              controller: _diagnosisController,
            ),
            const SizedBox(height: 16),
            const Text(
              'Prescribed Medications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ..._medications.map((med) {
                  return InputChip(
                    label: Text('${med['name']} (${med['frequency']})'),
                    onDeleted: () {
                      setState(() {
                        _medications.remove(med);
                      });
                    },
                    onPressed: () => _editMedication(med),
                    backgroundColor: Colors.blue.shade100,
                  );
                }),
                ActionChip(
                  label: const Text('Add Medication'),
                  avatar: const Icon(Icons.add),
                  onPressed: _addNewMedication,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _editMedication(Map<String, String> med) async {
    final nameController = TextEditingController(text: med['name']);
    final freqController = TextEditingController(text: med['frequency']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Medication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Medication Name'),
            ),
            TextField(
              controller: freqController,
              decoration: const InputDecoration(labelText: 'Frequency (e.g. BD, 1-0-1)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                med['name'] = nameController.text;
                med['frequency'] = freqController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewMedication() async {
    final nameController = TextEditingController();
    final freqController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Medication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Medication Name'),
            ),
            TextField(
              controller: freqController,
              decoration: const InputDecoration(labelText: 'Frequency (e.g. BD, 1-0-1)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  _medications.add({
                    'name': nameController.text,
                    'frequency': freqController.text,
                  });
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.controller,
    this.maxLines = 3,
  });

  final String title;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
            ),
          ),
        ],
      ),
    );
  }
}
