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
  }

  @override
  void dispose() {
    _currentSymptomsController.dispose();
    _premorbidPersonalityController.dispose();
    _pastHistoryController.dispose();
    _familyHistoryController.dispose();
    _diagnosisController.dispose();
    for (var controller in _mseControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildSection(String title, TextEditingController controller, {int maxLines = 3}) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Assessment Report'),
        actions: [
          TextButton.icon(
            onPressed: widget.onVerify,
            icon: const Icon(Icons.check_circle),
            label: const Text('Verify & Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Current Symptoms (HPI)', _currentSymptomsController),
          _buildSection('Premorbid Personality', _premorbidPersonalityController),
          _buildSection('Past History', _pastHistoryController),
          _buildSection('Family History', _familyHistoryController),
          
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
                  return _buildSection(
                    entry.key.replaceAll('_', ' ').toUpperCase(),
                    entry.value,
                    maxLines: 1,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSection('Provided Diagnosis', _diagnosisController),
        ],
      ),
    );
  }
}
