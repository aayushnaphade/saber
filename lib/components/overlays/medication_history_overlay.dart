import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saber/data/api/medication_history_service.dart';
import 'package:saber/data/models/medication_history_models.dart';

class MedicationHistoryOverlay extends StatefulWidget {
  final String patientId;
  final VoidCallback? onClose;

  const MedicationHistoryOverlay({
    super.key,
    required this.patientId,
    this.onClose,
  });

  @override
  State<MedicationHistoryOverlay> createState() =>
      _MedicationHistoryOverlayState();
}

class _MedicationHistoryOverlayState extends State<MedicationHistoryOverlay> {
  PatientMedicationHistory? _history;
  var _isLoading = true;
  var _timeFilter = '6m'; // '3m', '6m', '1y', 'all'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await MedicationHistoryService.getMedicationHistory(
        widget.patientId,
      );
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load medication history: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 600,
      height: 400,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_history == null || _history!.lifespans.isEmpty)
            const Expanded(
              child: Center(child: Text('No medication history found')),
            )
          else
            Expanded(child: _buildTimeline(theme)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Medication History',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildFilterChip('3m'),
          const SizedBox(width: 8),
          _buildFilterChip('6m'),
          const SizedBox(width: 8),
          _buildFilterChip('1y'),
          const SizedBox(width: 8),
          _buildFilterChip('all'),
          const SizedBox(width: 16),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _timeFilter == label;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => setState(() => _timeFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(ThemeData theme) {
    final now = DateTime.now();
    DateTime startDate;
    switch (_timeFilter) {
      case '3m':
        startDate = now.subtract(const Duration(days: 90));
      case '6m':
        startDate = now.subtract(const Duration(days: 180));
      case '1y':
        startDate = now.subtract(const Duration(days: 365));
      default:
        startDate = _history!.lifespans.isEmpty
            ? now.subtract(const Duration(days: 365))
            : _history!.lifespans
                  .map((l) => l.startDate)
                  .reduce((a, b) => a.isBefore(b) ? a : b);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimelineRuler(constraints.maxWidth - 100, startDate, now),
              const SizedBox(height: 16),
              ..._history!.lifespans.map(
                (lifespan) => _buildMedicationRow(
                  lifespan,
                  constraints.maxWidth - 100,
                  startDate,
                  now,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineRuler(double width, DateTime start, DateTime end) {
    final theme = Theme.of(context);
    final duration = end.difference(start).inDays;
    if (duration <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 100),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (i) {
          final date = start.add(Duration(days: (duration * i / 3).round()));
          return Text(
            DateFormat('MMM yy').format(date),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMedicationRow(
    MedicationLifespan lifespan,
    double width,
    DateTime rulerStart,
    DateTime rulerEnd,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              lifespan.name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 30,
              child: Stack(
                children: [
                  // Timeline Bar Background
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Active Lifespan Line
                  ..._buildLifespanLines(lifespan, width, rulerStart, rulerEnd),
                  // Event Markers
                  ...lifespan.events.map(
                    (event) =>
                        _buildEventMarker(event, width, rulerStart, rulerEnd),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLifespanLines(
    MedicationLifespan lifespan,
    double width,
    DateTime rulerStart,
    DateTime rulerEnd,
  ) {
    final theme = Theme.of(context);
    final totalDays = rulerEnd.difference(rulerStart).inDays;
    if (totalDays <= 0) return [];

    final List<Widget> lines = [];
    DateTime? segmentStart;

    for (int i = 0; i < lifespan.events.length; i++) {
      final event = lifespan.events[i];

      if (event.type == MedicationEventType.started) {
        segmentStart = event.date;
      } else if (event.type == MedicationEventType.stopped &&
          segmentStart != null) {
        lines.add(
          _buildSegment(
            segmentStart,
            event.date,
            width,
            rulerStart,
            totalDays,
            theme,
          ),
        );
        segmentStart = null;
      }

      // If it's the last event and not stopped, draw until today
      if (i == lifespan.events.length - 1 && segmentStart != null) {
        lines.add(
          _buildSegment(
            segmentStart,
            rulerEnd,
            width,
            rulerStart,
            totalDays,
            theme,
            isActive: true,
          ),
        );
      }
    }

    return lines;
  }

  Widget _buildSegment(
    DateTime start,
    DateTime end,
    double width,
    DateTime rulerStart,
    int totalDays,
    ThemeData theme, {
    bool isActive = false,
  }) {
    // Clip dates to ruler bounds
    final effectiveStart = start.isBefore(rulerStart) ? rulerStart : start;
    final effectiveEnd = end.isAfter(DateTime.now()) ? DateTime.now() : end;

    if (effectiveEnd.isBefore(rulerStart)) return const SizedBox.shrink();

    final left =
        (effectiveStart.difference(rulerStart).inDays / totalDays) * width;
    final right =
        (effectiveEnd.difference(rulerStart).inDays / totalDays) * width;
    final segmentWidth = right - left;

    if (segmentWidth <= 0) return const SizedBox.shrink();

    return Positioned(
      left: left,
      top: 12,
      bottom: 12,
      child: Container(
        width: segmentWidth,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(
            alpha: isActive ? 0.6 : 0.3,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildEventMarker(
    MedicationEvent event,
    double width,
    DateTime rulerStart,
    DateTime rulerEnd,
  ) {
    if (event.date.isBefore(rulerStart)) return const SizedBox.shrink();

    final totalDays = rulerEnd.difference(rulerStart).inDays;
    final left = (event.date.difference(rulerStart).inDays / totalDays) * width;

    return Positioned(
      left: left - 10,
      top: 5,
      child: Tooltip(
        message:
            '${event.typeLabel}: ${event.dose ?? ''} (${event.frequency ?? ''})\n${DateFormat('MMM dd, yyyy').format(event.date)}\n${event.remarks ?? ''}',
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: event.color, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(event.icon, size: 14, color: event.color),
        ),
      ),
    );
  }
}
