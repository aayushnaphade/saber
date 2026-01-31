import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saber/data/models/vitals.dart';
import 'package:saber/design_system/colors.dart';

class VitalsOverlayCard extends StatefulWidget {
  final List<Vitals> vitalsHistory;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final bool isExpanded;

  const VitalsOverlayCard({
    super.key,
    required this.vitalsHistory,
    this.onTap,
    this.onClose,
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
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vitalsHistory.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
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
          const Icon(Icons.monitor_heart_outlined, size: 16, color: Colors.pink),
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
        ],
      ),
    );
  }

  Widget _buildCompactSummary(ThemeData theme, Vitals vitals) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (vitals.systolic != null && vitals.diastolic != null)
            _buildVitalItem(theme, 'BP', '${vitals.systolic}/${vitals.diastolic}'),
          if (vitals.heartRate != null)
            _buildVitalItem(theme, 'HR', '${vitals.heartRate}'),
          if (vitals.weight != null)
            _buildVitalItem(theme, 'Wt', '${vitals.weight}'),
        ],
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
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildExpandedDetails(ThemeData theme) {
    // Only show last 5 records for clarity
    final history = widget.vitalsHistory.take(5).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.vitalsHistory.length > 1) ...[
               Text(
                'Trends',
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                width: double.infinity,
                child: CustomPaint(
                  painter: TrendsPainter(
                    vitals: widget.vitalsHistory.take(10).toList().reversed.toList(),
                    color: Colors.pink,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'History',
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...history.map((v) => _buildHistoryRow(theme, v)),
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
        border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5))),
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
                  Text('${vitals.systolic}/${vitals.diastolic} mmHg', style: theme.textTheme.bodySmall),
                if (vitals.heartRate != null)
                  Text('${vitals.heartRate} bpm', style: theme.textTheme.bodySmall),
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

class TrendsPainter extends CustomPainter {
  final List<Vitals> vitals;
  final Color color;

  TrendsPainter({required this.vitals, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (vitals.length < 2) return;

    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw BP (Systolic) line
    // Find min/max for normalization
    final systolics = vitals.where((v) => v.systolic != null).map((v) => v.systolic!).toList();
    if (systolics.isEmpty) return;
    
    final minVal = systolics.reduce((a, b) => a < b ? a : b).toDouble();
    final maxVal = systolics.reduce((a, b) => a > b ? a : b).toDouble();
    final range = maxVal - minVal == 0 ? 10 : maxVal - minVal;

    final path = Path();
    final spacing = size.width / (vitals.length - 1);

    for (int i = 0; i < vitals.length; i++) {
      if (vitals[i].systolic == null) continue;
      
      final x = i * spacing;
      final y = size.height - ((vitals[i].systolic! - minVal) / range * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
