import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/design_system/animations.dart';
import 'package:saber/design_system/radius.dart';
import 'package:saber/design_system/spacing.dart';
import 'package:saber/pages/home/dashboard/widgets/new_patient_dialog.dart';
import 'package:saber/pages/home/dashboard/widgets/vitals_dialog.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        label: 'New Patient',
        icon: Icons.person_add_outlined,
        color: Colors.blue,
        onTap: () async {
          final patient = await showDialog<Patient>(
            context: context,
            builder: (context) => const NewPatientDialog(),
          );

          if (patient != null && context.mounted) {
            await showDialog(
              context: context,
              builder: (context) => VitalsDialog(
                patientId: patient.id,
                patientName: patient.fullName,
                isNewPatient: true,
              ),
            );
          }
        },
      ),
      (
        label: 'Follow Patient',
        icon: Icons.people_outline,
        color: Colors.green,
        onTap: () {
          context.go('/home/browse');
        },
      ),
      (
        label: 'History',
        icon: Icons.history_outlined,
        color: Colors.purple,
        onTap: () {
          context.go('/home/history');
        },
      ),
    ];

    if (stows.userRole.value == 'doctor') {
      actions.add((
        label: 'Team',
        icon: Icons.manage_accounts_outlined,
        color: Colors.orange,
        onTap: () {
          context.go('/home/team');
          return null;
        },
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine number of columns based on available width
        // Assuming min item width of around 140px
        final int crossAxisCount = (constraints.maxWidth / 140).floor().clamp(
          2,
          4,
        );
        const double spacing = AppSpacing.md;
        final double itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * spacing) /
            crossAxisCount;

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
    return _QuickActionButton(
      label: label,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  var _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: 1.0,
        end: _isPressed ? AppAnimations.buttonPressScale : 1.0,
      ),
      duration: AppAnimations.buttonPress,
      curve: AppAnimations.buttonPressCurve,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
                borderRadius: AppRadius.lgRadius,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
