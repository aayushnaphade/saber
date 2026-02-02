import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:saber/i18n/strings.g.dart';

class ReportView extends StatefulWidget {
  const ReportView({
    super.key,
    required this.reportData,
    required this.onVerify,
    this.onRegenerate,
    this.readonly = false,
  });

  final Map<String, dynamic> reportData;
  final VoidCallback onVerify;
  final VoidCallback? onRegenerate;
  final bool readonly;

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
    _currentSymptomsController = TextEditingController(
      text: widget.reportData['current_symptoms'] ?? '',
    );
    _premorbidPersonalityController = TextEditingController(
      text: widget.reportData['premorbid_personality'] ?? '',
    );
    _pastHistoryController = TextEditingController(
      text: widget.reportData['past_history'] ?? '',
    );
    _familyHistoryController = TextEditingController(
      text: widget.reportData['family_history'] ?? '',
    );
    _diagnosisController = TextEditingController(
      text: widget.reportData['provided_diagnosis'] ?? '',
    );

    final mse = widget.reportData['mental_status_examination'];
    if (mse is Map) {
      mse.forEach((key, value) {
        _mseControllers[key.toString()] = TextEditingController(
          text: value?.toString() ?? '',
        );
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
            'duration': m['duration']?.toString() ?? '',
            'remarks': m['remarks']?.toString() ?? '',
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
    if (widget.readonly) {
      return _buildBentoLayout(context);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Clinical Assessment Report'),
        actions: [
          if (widget.onRegenerate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: widget.onRegenerate,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'Regenerate',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(
                    color: Colors.orange.shade700.withValues(alpha: 0.5),
                  ),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade500, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: _syncAndVerify,
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Verify & Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBentoLayout(context),
    );
  }

  void _syncAndVerify() {
    // Sync logic remains the same as controllers are updated in real-time
    widget.reportData['current_symptoms'] = _currentSymptomsController.text;
    widget.reportData['premorbid_personality'] =
        _premorbidPersonalityController.text;
    widget.reportData['past_history'] = _pastHistoryController.text;
    widget.reportData['family_history'] = _familyHistoryController.text;
    widget.reportData['provided_diagnosis'] = _diagnosisController.text;
    widget.reportData['mental_status_examination'] = Map.fromEntries(
      _mseControllers.entries.map((e) => MapEntry(e.key, e.value.text)),
    );
    widget.reportData['medications'] = _medications;
    widget.onVerify();
  }

  Widget _buildBentoLayout(BuildContext context) {
    // Theme Awareness
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Bento Colors (Light/Dark variants)
    final diagnosisColor = isDark
        ? Colors.deepPurple.shade900.withOpacity(0.3)
        : Colors.purple.shade50;
    final symptomsColor = isDark
        ? Colors.blue.shade900.withOpacity(0.3)
        : Colors.blue.shade50;
    final medicationsColor = isDark
        ? Colors.green.shade900.withOpacity(0.3)
        : Colors.green.shade50;
    final mseColor = isDark
        ? Colors.teal.shade900.withOpacity(0.3)
        : Colors.teal.shade50;
    final premorbidColor = isDark
        ? Colors.orange.shade900.withOpacity(0.3)
        : Colors.orange.shade50;

    // New Colors for History Sections
    final pastHistoryColor = isDark
        ? Colors.amber.shade900.withOpacity(0.3)
        : Colors.amber.shade50;
    final familyHistoryColor = isDark
        ? Colors.pink.shade900.withOpacity(0.3)
        : Colors.pink.shade50;

    // Helpers
    bool hasText(TextEditingController c) => c.text.trim().isNotEmpty;
    final isEditing = !widget.readonly;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: StaggeredGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          // Diagnosis (Full Width)
          if (isEditing || hasText(_diagnosisController))
            StaggeredGridTile.fit(
              crossAxisCellCount: 2,
              child: _BentoCard(
                title: 'Diagnosis',
                controller: _diagnosisController,
                readOnly: widget.readonly,
                color: diagnosisColor,
                icon: Icons.local_hospital,
                iconColor: isDark
                    ? Colors.purple.shade200
                    : Colors.purple.shade300,
                isLarge: true,
              ),
            ),

          // Symptoms (Half Width)
          if (isEditing || hasText(_currentSymptomsController))
            StaggeredGridTile.fit(
              crossAxisCellCount: 1,
              child: _BentoCard(
                title: 'Symptoms',
                controller: _currentSymptomsController,
                readOnly: widget.readonly,
                color: symptomsColor,
                icon: Icons.sick,
                iconColor: isDark ? Colors.blue.shade200 : Colors.blue.shade300,
              ),
            ),

          // Medications (Half Width)
          if (isEditing || _medications.isNotEmpty)
            StaggeredGridTile.fit(
              crossAxisCellCount: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: medicationsColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                  border: isDark ? Border.all(color: Colors.white10) : null,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medication,
                          color: isDark
                              ? Colors.green.shade200
                              : Colors.green.shade300,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Plan / Medications',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMedicationChips(
                      readonly: widget.readonly,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

          // MSE (Full Width)
          if (isEditing || _mseControllers.isNotEmpty)
            StaggeredGridTile.fit(
              crossAxisCellCount: 2,
              child: _BentoCard(
                title: 'Mental Status',
                content: widget.readonly
                    ? _mseControllers.entries
                          .map(
                            (e) =>
                                '${e.key.replaceAll('_', ' ').toUpperCase()}: ${e.value.text}',
                          )
                          .join('\n')
                    : null,
                customChild: !widget.readonly
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _mseControllers.entries
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: TextField(
                                  controller: e.value,
                                  style: theme.textTheme.bodyMedium,
                                  decoration: InputDecoration(
                                    labelText: e.key
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                    border: const UnderlineInputBorder(),
                                    isDense: true,
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.black12,
                                      ),
                                    ),
                                  ),
                                  maxLines: null,
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : null,
                readOnly: widget.readonly,
                color: mseColor,
                icon: Icons.psychology,
                iconColor: isDark ? Colors.teal.shade200 : Colors.teal.shade300,
              ),
            ),

          // Past History & Family History (Split or Full depending on content)
          if (isEditing || hasText(_pastHistoryController))
            StaggeredGridTile.fit(
              crossAxisCellCount:
                  (isEditing || hasText(_familyHistoryController)) ? 1 : 2,
              child: _BentoCard(
                title: 'Past History',
                controller: _pastHistoryController,
                readOnly: widget.readonly,
                color: pastHistoryColor,
                icon: Icons.history,
                iconColor: isDark
                    ? Colors.amber.shade200
                    : Colors.amber.shade600,
              ),
            ),

          if (isEditing || hasText(_familyHistoryController))
            StaggeredGridTile.fit(
              crossAxisCellCount: (isEditing || hasText(_pastHistoryController))
                  ? 1
                  : 2,
              child: _BentoCard(
                title: 'Family History',
                controller: _familyHistoryController,
                readOnly: widget.readonly,
                color: familyHistoryColor,
                icon: Icons.family_restroom,
                iconColor: isDark ? Colors.pink.shade200 : Colors.pink.shade300,
              ),
            ),

          // Premorbid Personality
          if (isEditing || hasText(_premorbidPersonalityController))
            StaggeredGridTile.fit(
              crossAxisCellCount: 2,
              child: _BentoCard(
                title: 'Premorbid Personality',
                controller: _premorbidPersonalityController,
                readOnly: widget.readonly,
                color: premorbidColor,
                icon: Icons.person_outline,
                iconColor: isDark
                    ? Colors.orange.shade200
                    : Colors.orange.shade300,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicationChips({required bool readonly, required bool isDark}) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        ..._medications.map((med) {
          final summary = StringBuffer(med['name'] ?? '');
          if (med['frequency']?.isNotEmpty == true)
            summary.write(' (${med['frequency']})');
          if (med['duration']?.isNotEmpty == true &&
              med['duration'] != 'Not mentioned')
            summary.write(' - ${med['duration']}');
          if (med['remarks']?.isNotEmpty == true &&
              med['remarks'] != 'Not mentioned')
            summary.write(' (${med['remarks']})');
          return InputChip(
            label: Text(
              summary.toString(),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            onDeleted: readonly
                ? null
                : () {
                    setState(() {
                      _medications.remove(med);
                    });
                  },
            onPressed: readonly ? null : () => _editMedication(med),
            backgroundColor: isDark ? Colors.white10 : Colors.white,
            deleteIconColor: isDark ? Colors.white70 : null,
            elevation: isDark ? 0 : 1,
            shadowColor: Colors.black.withOpacity(0.1),
            side: isDark ? BorderSide.none : null,
          );
        }),
        if (!readonly)
          ActionChip(
            label: Text(
              'Add',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
            avatar: Icon(
              Icons.add,
              size: 16,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            onPressed: _addNewMedication,
            backgroundColor: isDark ? Colors.white10 : Colors.white,
            elevation: isDark ? 0 : 1,
            side: isDark ? BorderSide.none : null,
          ),
      ],
    );
  }

  Future<void> _editMedication(Map<String, String> med) async {
    final nameController = TextEditingController(text: med['name']);
    final freqController = TextEditingController(text: med['frequency']);
    final durationController = TextEditingController(text: med['duration']);
    final remarksController = TextEditingController(text: med['remarks']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Medication'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Medication Name'),
              ),
              TextField(
                controller: freqController,
                decoration: const InputDecoration(
                  labelText: 'Frequency (e.g. BD, 1-0-1)',
                ),
              ),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (e.g. 5 days)',
                ),
              ),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (e.g. after food)',
                ),
              ),
            ],
          ),
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
                med['duration'] = durationController.text;
                med['remarks'] = remarksController.text;
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
    final durationController = TextEditingController();
    final remarksController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Medication'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Medication Name'),
              ),
              TextField(
                controller: freqController,
                decoration: const InputDecoration(
                  labelText: 'Frequency (e.g. BD, 1-0-1)',
                ),
              ),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (e.g. 5 days)',
                ),
              ),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (e.g. after food)',
                ),
              ),
            ],
          ),
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
                    'duration': durationController.text,
                    'remarks': remarksController.text,
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

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.title,
    this.content,
    this.controller,
    required this.color,
    required this.icon,
    required this.iconColor,
    this.isLarge = false,
    this.readOnly = true,
    this.customChild,
  });

  final String title;
  final String? content;
  final TextEditingController? controller;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final bool isLarge;
  final bool readOnly;
  final Widget? customChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
        border: isDark ? Border.all(color: Colors.white10) : null,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: isLarge ? 24 : 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isLarge ? 18 : 16,
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (customChild != null)
            customChild!
          else if (!readOnly && controller != null)
            TextField(
              controller: controller,
              maxLines: null, // Allow multiline growth
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isLarge ? 16 : 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Type to add content...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.grey,
                ),
              ),
            )
          else
            Text(
              (content != null && content!.isNotEmpty)
                  ? content!
                  : (controller?.text.isNotEmpty == true
                        ? controller!.text
                        : 'Not mentioned'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isLarge ? 16 : 14,
                height: 1.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
        ],
      ),
    );
  }
}
