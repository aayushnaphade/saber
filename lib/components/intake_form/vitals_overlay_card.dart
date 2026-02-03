import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saber/data/models/vitals.dart';
import 'package:saber/design_system/colors.dart';

class VitalsOverlayCard extends StatefulWidget {
  final List<Vitals> vitalsHistory;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final ValueChanged<bool>? onExpandChanged;
  final bool isExpanded;

  const VitalsOverlayCard({
    super.key,
    required this.vitalsHistory,
    this.onTap,
    this.onClose,
    this.onExpandChanged,
    this.isExpanded = false,
  });

  @override
  State<VitalsOverlayCard> createState() => _VitalsOverlayCardState();
}

class _VitalsOverlayCardState extends State<VitalsOverlayCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

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
  void didUpdateWidget(covariant VitalsOverlayCard oldWidget) {
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

    // Show empty state if no vitals data
    if (widget.vitalsHistory.isEmpty) {
      return Container(
        width: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.pink.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.monitor_heart_outlined,
                    size: 16,
                    color: Colors.pink,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Vitals',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                  ),
                  if (widget.onClose != null) ...[
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
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.monitor_heart_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No vitals recorded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final latest = widget.vitalsHistory.first;

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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.pink.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              if (!_isExpanded) _buildCompactSummary(theme, latest),
              if (_isExpanded) _buildExpandedDetails(theme),
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
        color: Colors.pink.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.monitor_heart_outlined,
            size: 16,
            color: Colors.pink,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Vitals',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.pink,
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
                color: Colors.pink,
              ),
            ),
          ),
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

  Widget _buildCompactSummary(ThemeData theme, Vitals vitals) {
    final hasAnyVitals =
        vitals.systolic != null ||
        vitals.diastolic != null ||
        vitals.heartRate != null ||
        vitals.weight != null;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: hasAnyVitals
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (vitals.systolic != null && vitals.diastolic != null)
                  _buildVitalItem(
                    theme,
                    'BP',
                    '${vitals.systolic}/${vitals.diastolic}',
                  ),
                if (vitals.heartRate != null)
                  _buildVitalItem(theme, 'HR', '${vitals.heartRate}'),
                if (vitals.weight != null)
                  _buildVitalItem(theme, 'Wt', '${vitals.weight}'),
              ],
            )
          : Text(
              'No values recorded',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
    );
  }

  Widget _buildVitalItem(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedDetails(ThemeData theme) {
    // Only show last 5 records for clarity in the list
    final historyList = widget.vitalsHistory.take(5).toList();
    // Use last 10 for trends
    final trendData = widget.vitalsHistory.take(10).toList().reversed.toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.vitalsHistory.isNotEmpty) ...[
              Text(
                'Blood Pressure Trends',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                width: double.infinity,
                child: CustomPaint(
                  painter: TrendsPainter(
                    vitals: trendData,
                    color: Colors.pink,
                    type: _TrendType.bloodPressure,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Weight Trends',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                width: double.infinity,
                child: CustomPaint(
                  painter: TrendsPainter(
                    vitals: trendData,
                    color: Colors.blue,
                    type: _TrendType.weight,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'History',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...historyList.map((v) => _buildHistoryRow(theme, v)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow(ThemeData theme, Vitals vitals) {
    final dateFormat = DateFormat('MM/dd HH:mm');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Text(
            dateFormat.format(vitals.capturedAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (vitals.systolic != null)
                  Text(
                    '${vitals.systolic}/${vitals.diastolic} mmHg',
                    style: theme.textTheme.bodySmall,
                  ),
                if (vitals.heartRate != null)
                  Text(
                    '${vitals.heartRate} bpm',
                    style: theme.textTheme.bodySmall,
                  ),
                if (vitals.weight != null)
                  Text('${vitals.weight} kg', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TrendType { bloodPressure, weight }

class TrendsPainter extends CustomPainter {
  final List<Vitals> vitals;
  final Color color;
  final _TrendType type;

  TrendsPainter({
    required this.vitals,
    required this.color,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (vitals.isEmpty) return;

    final paintStroke = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final paintFill = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Filter valid data points based on type
    final validVitals = vitals.where((v) {
      if (type == _TrendType.bloodPressure) {
        return v.systolic != null && v.diastolic != null;
      } else {
        return v.weight != null;
      }
    }).toList();

    if (validVitals.isEmpty) return;

    // Calculate Y-axis range
    double minVal, maxVal;
    if (type == _TrendType.bloodPressure) {
      final allValues = [
        ...validVitals.map((v) => v.systolic!),
        ...validVitals.map((v) => v.diastolic!),
      ];
      minVal = allValues.reduce((a, b) => a < b ? a : b).toDouble();
      maxVal = allValues.reduce((a, b) => a > b ? a : b).toDouble();
      // Add padding
      minVal -= 10;
      maxVal += 10;
    } else {
      final weights = validVitals.map((v) => v.weight!).toList();
      minVal = weights.reduce((a, b) => a < b ? a : b).toDouble();
      maxVal = weights.reduce((a, b) => a > b ? a : b).toDouble();
      // Add padding
      minVal -= 2;
      maxVal += 2;
    }

    // Ensure range is at least something to avoid divide by zero
    double range = maxVal - minVal;
    if (range <= 0) range = 10;

    final spacing =
        size.width / (validVitals.length > 1 ? validVitals.length - 1 : 1);

    // Draw logic
    if (type == _TrendType.bloodPressure) {
      _drawBPGraph(
        canvas,
        size,
        validVitals,
        minVal,
        range,
        spacing,
        paintStroke,
        paintDot,
        paintFill,
      );
    } else {
      _drawWeightGraph(
        canvas,
        size,
        validVitals,
        minVal,
        range,
        spacing,
        paintStroke,
        paintDot,
      );
    }
  }

  void _drawBPGraph(
    Canvas canvas,
    Size size,
    List<Vitals> data,
    double minVal,
    double range,
    double spacing,
    Paint strokePaint,
    Paint dotPaint,
    Paint fillPaint,
  ) {
    // Draw shaded area between systolic and diastolic
    final path = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (data.length == 1) ? size.width / 2 : i * spacing;
      final ySys =
          size.height - ((data[i].systolic! - minVal) / range * size.height);
      final yDia =
          size.height - ((data[i].diastolic! - minVal) / range * size.height);

      // Draw vertical connector
      canvas.drawLine(
        Offset(x, ySys),
        Offset(x, yDia),
        strokePaint..strokeWidth = 1,
      );

      // Draw dots
      canvas.drawCircle(Offset(x, ySys), 3, dotPaint);
      canvas.drawCircle(Offset(x, yDia), 3, dotPaint);

      // Connect lines if not first point and we have multiple points
      if (i > 0) {
        final prevX = (i - 1) * spacing;
        final prevYSys =
            size.height -
            ((data[i - 1].systolic! - minVal) / range * size.height);
        final prevYDia =
            size.height -
            ((data[i - 1].diastolic! - minVal) / range * size.height);

        canvas.drawLine(
          Offset(prevX, prevYSys),
          Offset(x, ySys),
          strokePaint..strokeWidth = 2,
        );
        canvas.drawLine(
          Offset(prevX, prevYDia),
          Offset(x, yDia),
          strokePaint..strokeWidth = 2,
        );
      }
    }
  }

  void _drawWeightGraph(
    Canvas canvas,
    Size size,
    List<Vitals> data,
    double minVal,
    double range,
    double spacing,
    Paint strokePaint,
    Paint dotPaint,
  ) {
    for (int i = 0; i < data.length; i++) {
      final x = (data.length == 1) ? size.width / 2 : i * spacing;
      final y =
          size.height - ((data[i].weight! - minVal) / range * size.height);

      canvas.drawCircle(Offset(x, y), 3, dotPaint);

      if (i > 0) {
        final prevX = (i - 1) * spacing;
        final prevY =
            size.height -
            ((data[i - 1].weight! - minVal) / range * size.height);
        canvas.drawLine(Offset(prevX, prevY), Offset(x, y), strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
