import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ExpandablePatientProgress extends StatefulWidget {
  const ExpandablePatientProgress({super.key});

  @override
  State<ExpandablePatientProgress> createState() =>
      _ExpandablePatientProgressState();
}

class _ExpandablePatientProgressState extends State<ExpandablePatientProgress>
    with SingleTickerProviderStateMixin {
  var _isExpanded = false;
  final _stats = <String, int>{'improving': 0, 'stable': 0, 'deteriorating': 0};
  var _isLoading = true;
  var _offset = const Offset(24, 24); // Bottom-right initial offset

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    /* try {
      final stats = await SupabaseConsultationService.getPatientProgressStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } */
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final improving = _stats['improving'] ?? 0;
    final stable = _stats['stable'] ?? 0;
    final deteriorating = _stats['deteriorating'] ?? 0;
    final total = improving + stable + deteriorating;

    return Positioned(
      right: _offset.dx,
      bottom: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          if (!_isExpanded) {
            setState(() {
              _offset = Offset(
                (_offset.dx - details.delta.dx).clamp(
                  16.0,
                  MediaQuery.of(context).size.width - 80.0,
                ),
                (_offset.dy - details.delta.dy).clamp(
                  16.0,
                  MediaQuery.of(context).size.height - 80.0,
                ),
              );
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutQuart,
          width: _isExpanded ? 320 : 64,
          height: _isExpanded ? 400 : 64,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(_isExpanded ? 24 : 32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
                if (_isExpanded && _isLoading) {
                  _loadStats();
                }
              },
              borderRadius: BorderRadius.circular(_isExpanded ? 24 : 32),
              child: _isExpanded
                  ? _buildExpandedContent(total)
                  : _buildCollapsedContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
          if (!_isLoading && _stats.values.any((v) => v > 0))
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(int total) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Patient Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _isExpanded = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(height: 24),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (total == 0)
            const Expanded(child: Center(child: Text('No data yet')))
          else ...[
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 45,
                  sections: [
                    if (_stats['improving']! > 0)
                      PieChartSectionData(
                        color: Colors.green,
                        value: _stats['improving']!.toDouble(),
                        title: '',
                        radius: 15,
                      ),
                    if (_stats['stable']! > 0)
                      PieChartSectionData(
                        color: Colors.orange,
                        value: _stats['stable']!.toDouble(),
                        title: '',
                        radius: 15,
                      ),
                    if (_stats['deteriorating']! > 0)
                      PieChartSectionData(
                        color: Colors.red,
                        value: _stats['deteriorating']!.toDouble(),
                        title: '',
                        radius: 15,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildStatRow(
              'Improving',
              _stats['improving']!,
              total > 0 ? (_stats['improving']! / total * 100) : 0,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              'Stable',
              _stats['stable']!,
              total > 0 ? (_stats['stable']! / total * 100) : 0,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              'Deteriorating',
              _stats['deteriorating']!,
              total > 0 ? (_stats['deteriorating']! / total * 100) : 0,
              Colors.red,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    int count,
    double percentage,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(
          '(${percentage.toStringAsFixed(0)}%)',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}
