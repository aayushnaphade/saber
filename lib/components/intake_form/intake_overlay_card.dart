import 'package:flutter/material.dart';
import 'package:saber/data/models/psychiatric_intake.dart';
import 'package:saber/design_system/colors.dart';

/// Compact Intake Card Widget
/// Displays a summary of the psychiatric intake form as an overlay
/// during the session note-taking canvas
class IntakeOverlayCard extends StatefulWidget {
  final PsychiatricIntake intake;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onExpandChanged;
  final bool isExpanded;

  const IntakeOverlayCard({
    super.key,
    required this.intake,
    this.onTap,
    this.onClose,
    this.onEdit,
    this.onExpandChanged,
    this.isExpanded = false,
  });

  @override
  State<IntakeOverlayCard> createState() => _IntakeOverlayCardState();
}

class _IntakeOverlayCardState extends State<IntakeOverlayCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  var _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant IntakeOverlayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      _isExpanded = widget.isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    if (widget.onExpandChanged != null) {
      widget.onExpandChanged!(!_isExpanded);
    } else {
      setState(() {
        _isExpanded = !_isExpanded;
        if (_isExpanded) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symptoms = widget.intake.getActiveSymptoms();
    final categories = widget.intake.getSymptomCategoryCounts();

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Container(
          width: _isExpanded ? 320 : 200,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: MedicalColors.info.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(theme),

              // Compact Summary
              if (!_isExpanded) _buildCompactSummary(theme, categories),

              // Expanded Details
              if (_isExpanded) ...[
                _buildExpandedDetails(theme, symptoms, categories),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MedicalColors.info.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 16,
            color: MedicalColors.info,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Intake Summary',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: MedicalColors.info,
              ),
            ),
          ),
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: MedicalColors.info,
              ),
            ),
          ),
          if (widget.onEdit != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Edit Intake Form',
              child: InkWell(
                onTap: widget.onEdit,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: MedicalColors.info,
                  ),
                ),
              ),
            ),
          ],
          if (widget.onClose != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactSummary(ThemeData theme, Map<String, int> categories) {
    final activeCats = categories.entries.where((e) => e.value > 0).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duration & Ref
          if (widget.intake.durationOfIllness != null) ...[
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.intake.durationOfIllness!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Category chips
          if (activeCats.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: activeCats.take(3).map((cat) {
                return _buildCategoryChip(theme, cat.key, cat.value);
              }).toList(),
            ),
            if (activeCats.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${activeCats.length - 3} more',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ] else
            Text(
              'Tap to expand',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),

          // Warning indicators
          if (widget.intake.suicidalThoughts ||
              widget.intake.suicidalPlans ||
              widget.intake.suicidalAttempts) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                    : MedicalColors.criticalBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.error.withValues(alpha: 0.5)
                      : MedicalColors.criticalBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 12,
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.error
                        : MedicalColors.critical,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Suicidal Risk',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.error
                          : MedicalColors.critical,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(
    ThemeData theme,
    List<String> symptoms,
    Map<String, int> categories,
  ) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Details
            if (widget.intake.residence != null) ...[
              _buildDetailSection(theme, 'Demographics', [
                _buildDetailRow(
                  Icons.home_outlined,
                  'Residence',
                  widget.intake.residence!,
                ),
              ]),
              const SizedBox(height: 12),
            ],

            // Clinical Info
            _buildDetailSection(theme, 'Clinical Info', [
              if (widget.intake.durationOfIllness != null)
                _buildDetailRow(
                  Icons.access_time,
                  'Duration',
                  widget.intake.durationOfIllness!,
                ),
              if (widget.intake.referredBy != null)
                _buildDetailRow(
                  Icons.person_outline,
                  'Referred by',
                  widget.intake.referredBy!,
                ),
              if (widget.intake.precipitatingFactor != null)
                _buildDetailRow(
                  Icons.bolt_outlined,
                  'Precipitating Factor',
                  widget.intake.precipitatingFactor!,
                ),
            ]),
            const SizedBox(height: 12),

            // Symptom Categories
            _buildDetailSection(
              theme,
              'Symptom Categories',
              categories.entries.where((e) => e.value > 0).map((cat) {
                return _buildCategoryRow(theme, cat.key, cat.value);
              }).toList(),
            ),

            // Active Symptoms List
            if (symptoms.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailSection(theme, 'Active Symptoms', [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: symptoms.take(10).map((s) {
                    return Chip(
                      label: Text(s),
                      labelStyle: theme.textTheme.labelSmall,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
                if (symptoms.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${symptoms.length - 10} more symptoms',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ]),
            ],

            // Medical & Stresses
            if (widget.intake.medicalIllnesses != null ||
                widget.intake.stresses != null ||
                widget.intake.ongoingTreatment != null) ...[
              const SizedBox(height: 12),
              _buildDetailSection(theme, 'Additional', [
                if (widget.intake.medicalIllnesses != null)
                  _buildDetailRow(
                    Icons.medical_information_outlined,
                    'Medical',
                    widget.intake.medicalIllnesses!,
                  ),
                if (widget.intake.stresses != null)
                  _buildDetailRow(
                    Icons.psychology_outlined,
                    'Stresses',
                    widget.intake.stresses!,
                  ),
                if (widget.intake.ongoingTreatment != null)
                  _buildDetailRow(
                    Icons.medication_outlined,
                    'Treatment',
                    widget.intake.ongoingTreatment!,
                  ),
              ]),
            ],

            // Provisional Diagnosis
            if (widget.intake.provisionalDiagnosis != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.2,
                        )
                      : MedicalColors.infoBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : MedicalColors.infoBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provisional Diagnosis',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.primary
                            : MedicalColors.info,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.intake.provisionalDiagnosis!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],

            // Warning for suicidal risk
            if (widget.intake.suicidalThoughts ||
                widget.intake.suicidalPlans ||
                widget.intake.suicidalAttempts) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                      : MedicalColors.criticalBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.error.withValues(alpha: 0.5)
                        : MedicalColors.criticalBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: MedicalColors.critical,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SUICIDAL RISK ALERT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.brightness == Brightness.dark
                                  ? theme.colorScheme.error
                                  : MedicalColors.critical,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            [
                              if (widget.intake.suicidalThoughts) 'Thoughts',
                              if (widget.intake.suicidalPlans) 'Plans',
                              if (widget.intake.suicidalAttempts) 'Attempts',
                            ].join(' • '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.brightness == Brightness.dark
                                  ? theme.colorScheme.onErrorContainer
                                  : MedicalColors.critical,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    ThemeData theme,
    String title,
    List<Widget> children,
  ) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall,
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(ThemeData theme, String category, int count) {
    final color = _getCategoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$category ($count)',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCategoryRow(ThemeData theme, String category, int count) {
    final color = _getCategoryColor(category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(category, style: theme.textTheme.bodySmall)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Anxiety':
        return Colors.orange;
      case 'Psychotic':
        return Colors.purple;
      case 'Manic':
        return Colors.amber.shade700;
      case 'Depressive':
        return Colors.blue;
      case 'Cognitive':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}

/// Animated builder helper for smooth transitions
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
