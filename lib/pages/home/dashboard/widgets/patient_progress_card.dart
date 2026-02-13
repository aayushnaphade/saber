import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PatientProgressCard extends StatefulWidget {
  const PatientProgressCard({super.key});

  @override
  State<PatientProgressCard> createState() => _PatientProgressCardState();
}

class _PatientProgressCardState extends State<PatientProgressCard> {
  Map<String, int> _stats = {'improving': 0, 'stable': 0, 'deteriorating': 0};
  bool _isLoading = true;

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
    final improving = _stats['improving'] ?? 0;
    final stable = _stats['stable'] ?? 0;
    final deteriorating = _stats['deteriorating'] ?? 0;
    final total = improving + stable + deteriorating;

    // Calculate percentages
    final improvingPct = total > 0 ? (improving / total) * 100 : 0.0;
    final stablePct = total > 0 ? (stable / total) * 100 : 0.0;
    final deterioratingPct = total > 0 ? (deteriorating / total) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (total == 0)
            const Center(child: Text('No data yet'))
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 35,
                        sections: [
                          if (improving > 0)
                            PieChartSectionData(
                              color: Colors.green,
                              value: improving.toDouble(),
                              title: '',
                              radius: 12,
                            ),
                          if (stable > 0)
                            PieChartSectionData(
                              color: Colors.orange,
                              value: stable.toDouble(),
                              title: '',
                              radius: 12,
                            ),
                          if (deteriorating > 0)
                            PieChartSectionData(
                              color: Colors.red,
                              value: deteriorating.toDouble(),
                              title: '',
                              radius: 12,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _buildStatRow(
                        'Improving',
                        improving,
                        improvingPct,
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow('Stable', stable, stablePct, Colors.orange),
                      const SizedBox(height: 12),
                      _buildStatRow(
                        'Deteriorating',
                        deteriorating,
                        deterioratingPct,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
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
