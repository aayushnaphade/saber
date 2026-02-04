import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/supabase/supabase_dashboard_service.dart';
import 'package:saber/design_system/spacing.dart';

class ConsultationHistoryPage extends StatefulWidget {
  const ConsultationHistoryPage({super.key});

  @override
  State<ConsultationHistoryPage> createState() =>
      _ConsultationHistoryPageState();
}

class _ConsultationHistoryPageState extends State<ConsultationHistoryPage> {
  var _isLoading = true;
  var _filter = _HistoryFilter.today;
  List<Appointment> _allConsultations = [];
  List<Appointment> _filteredConsultations = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyLocalFilters();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime start;
      final end = now;

      switch (_filter) {
        case _HistoryFilter.today:
          start = DateTime(now.year, now.month, now.day);
        case _HistoryFilter.lastWeek:
          start = now.subtract(const Duration(days: 7));
        case _HistoryFilter.lastMonth:
          start = now.subtract(const Duration(days: 30));
      }

      final results = await SupabaseDashboardService.getConsultationHistory(
        start,
        end,
      );
      if (mounted) {
        setState(() {
          _allConsultations = results;
          _applyLocalFilters(); // Initial filter application
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyLocalFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredConsultations = List.from(_allConsultations);
      } else {
        _filteredConsultations = _allConsultations
            .where(
              (c) =>
                  c.patientName.toLowerCase().contains(query) ||
                  c.reason.toLowerCase().contains(query),
            )
            .toList();
      }
      // Sort by time descending
      _filteredConsultations.sort((a, b) => b.time.compareTo(a.time));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(HomeRoutes.getRoute(0)),
              ),
              title: const Text(
                'History',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: false,
              pinned: true,
              floating: true,
              snap: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () {
                    // TODO: Implement date picker range filter
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Date range picker coming soon'),
                      ),
                    );
                  },
                  tooltip: 'Select Date Range',
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search patients, symptoms...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Today', _HistoryFilter.today),
                          const SizedBox(width: AppSpacing.sm),
                          _buildFilterChip(
                            'Last 7 Days',
                            _HistoryFilter.lastWeek,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _buildFilterChip(
                            'Last 30 Days',
                            _HistoryFilter.lastMonth,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredConsultations.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              _buildGroupedList(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    // Group items by date
    final Map<String, List<Appointment>> grouped = {};
    for (final consultation in _filteredConsultations) {
      final dateKey = _getDateKey(consultation.time);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(consultation);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final consultations = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                dateKey,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...consultations.map((c) => _buildConsultationCard(c)),
          ],
        );
      }, childCount: grouped.length),
    );
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) return 'Today';
    if (itemDate == yesterday) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(date);
  }

  Widget _buildFilterChip(String label, _HistoryFilter filter) {
    final isSelected = _filter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filter = filter;
            _searchController.clear(); // Clear search as context changes
          });
          _loadHistory();
        }
      },
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selectedColor: Theme.of(context).colorScheme.secondaryContainer,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No history found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try adjusting your filters or search',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationCard(Appointment consultation) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeStr = DateFormat('h:mm a').format(consultation.time);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () {
          context.go(
            '${RoutePaths.patientDetail.replaceFirst(':patientId', consultation.patientId)}?returnPath=${Uri.encodeComponent('/home/history')}',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Time & Avatar
              Column(
                children: [
                  Text(
                    timeStr,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      consultation.patientName.isNotEmpty
                          ? consultation.patientName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            consultation.patientName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (consultation.age != null ||
                            consultation.gender != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              [
                                if (consultation.age != null)
                                  '${consultation.age}',
                                if (consultation.gender != null &&
                                    consultation.gender!.isNotEmpty)
                                  consultation.gender![0].toUpperCase(),
                              ].join(' • '),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      consultation.reason,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // ID Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ID: ${consultation.patientId}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Status & Arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _getStatusChip(consultation.status, context),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getStatusChip(AppointmentStatus status, BuildContext context) {
    Color color;

    switch (status) {
      case AppointmentStatus.completed:
        color = const Color(0xFF10B981); // Vibrant green
      case AppointmentStatus.cancelled:
        color = const Color(0xFFEF4444); // Vibrant red
      case AppointmentStatus.upcoming:
        color = const Color(0xFF3B82F6); // Vibrant blue
      case AppointmentStatus.inProgress:
        color = const Color(0xFFF59E0B); // Vibrant amber/orange
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

enum _HistoryFilter { today, lastWeek, lastMonth }
