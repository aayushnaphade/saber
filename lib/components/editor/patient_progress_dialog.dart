import 'package:flutter/material.dart';

class PatientProgressDialog extends StatefulWidget {
  const PatientProgressDialog({super.key});

  @override
  State<PatientProgressDialog> createState() => _PatientProgressDialogState();
}

class _PatientProgressDialogState extends State<PatientProgressDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Patient Progress'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'How is the patient progressing compared to the last session?',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          _buildOption(
            label: 'Improving',
            value: 'improving',
            color: Colors.green,
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 12),
          _buildOption(
            label: 'Stable',
            value: 'stable',
            color: Colors.orange,
            icon: Icons.trending_flat,
          ),
          const SizedBox(height: 12),
          _buildOption(
            label: 'Deteriorating',
            value: 'deteriorating',
            color: Colors.red,
            icon: Icons.trending_down,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(), // Return null if skipped
          child: const Text('Skip'),
        ),
      ],
    );
  }

  Widget _buildOption({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    // Define gradients based on the base color
    Gradient gradient;
    if (color == Colors.green) {
      gradient = LinearGradient(
        colors: [Colors.green.shade400, Colors.green.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (color == Colors.orange) {
      gradient = LinearGradient(
        colors: [Colors.orange.shade300, Colors.orange.shade800],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      gradient = LinearGradient(
        colors: [Colors.red.shade400, Colors.red.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(value),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
