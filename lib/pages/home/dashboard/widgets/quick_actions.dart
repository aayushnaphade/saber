import 'package:flutter/material.dart';
import 'package:saber/pages/home/dashboard/widgets/new_patient_dialog.dart';
import 'package:saber/pages/home/dashboard/widgets/schedule_appointment_dialog.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        label: 'New Patient',
        icon: Icons.person_add_outlined,
        color: Colors.blue,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => const NewPatientDialog(),
          );
        },
      ),
      (
        label: 'Schedule',
        icon: Icons.calendar_today_outlined,
        color: Colors.green,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => const ScheduleAppointmentDialog(),
          );
        },
      ),
      (
        label: 'Upload Scan',
        icon: Icons.upload_file_outlined,
        color: Colors.purple,
        onTap: () {},
      ),
      (
        label: 'Voice Note',
        icon: Icons.mic_none_outlined,
        color: Colors.orange,
        onTap: () {},
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine number of columns based on available width
        // Assuming min item width of around 140px
        final int crossAxisCount = (constraints.maxWidth / 140).floor().clamp(2, 4);
        final double spacing = 12;
        final double itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((action) {
            return SizedBox(
              width: itemWidth,
              child: _buildActionCard(
                context,
                action.label,
                action.icon,
                action.color,
                action.onTap,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
