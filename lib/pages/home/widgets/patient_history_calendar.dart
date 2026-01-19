import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_to_regexp/path_to_regexp.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/supabase/supabase_auth_service.dart';
import 'package:saber/data/supabase/supabase_consultation_service.dart';
import 'package:saber/components/loading/skeleton_loader.dart';
import 'package:saber/design_system/spacing.dart';

class PatientHistoryCalendar extends StatefulWidget {
  const PatientHistoryCalendar({super.key});

  @override
  State<PatientHistoryCalendar> createState() => _PatientHistoryCalendarState();
}

class _PatientHistoryCalendarState extends State<PatientHistoryCalendar> {
  var _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<PatientConsultation>> _events = {};
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadConsultations();
  }

  Future<void> _loadConsultations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doctorId = SupabaseAuthService.currentUser?.id;
      if (doctorId == null) {
        if (mounted) {
          setState(() {
            _events = {}; // Clear any mock/old data
            _isLoading = false;
          });
        }
        return;
      }

      // Load consultations for the current month and previous month
      final startDate = DateTime(
        _focusedDay.year,
        _focusedDay.month - 1,
        1,
      );
      final endDate = DateTime(
        _focusedDay.year,
        _focusedDay.month + 2,
        0,
      );

      final events = await SupabaseConsultationService
          .getConsultationsGroupedByDate(
        doctorId,
        startDate,
        endDate,
      );

      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _events = {}; // Clear any old/mock data on error
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading consultations: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadConsultations,
            ),
          ),
        );
      }
    }
  }

  List<PatientConsultation> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: _isLoading
          ? Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  // Calendar header skeleton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonLoader.rounded(width: 150, height: 32),
                      Row(
                        children: [
                          SkeletonLoader.circle(size: 32),
                          SizedBox(width: AppSpacing.sm),
                          SkeletonLoader.circle(size: 32),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  
                  // Calendar grid skeleton
                  ...List.generate(5, (rowIndex) => Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(7, (colIndex) => 
                        SkeletonLoader.circle(size: 40),
                      ),
                    ),
                  )),
                  
                  SizedBox(height: AppSpacing.lg),
                  
                  // Event list skeleton
                  ...List.generate(3, (index) => Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: SkeletonListTile(lineCount: 2),
                  )),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildDaysOfWeek(),
                _buildCalendarGrid(),
                const Divider(),
                _buildEventList(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
              });
              _loadConsultations(); // Reload data for new month
            },
          ),
          Text(
            DateFormat.yMMMM().format(_focusedDay),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              });
              _loadConsultations(); // Reload data for new month
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeek() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days
            .map(
              (day) => Text(
                day,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            )
            .toList(),
      ),
    );
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 12) {
      return DateTime(year + 1, 1, 0).day;
    }
    return DateTime(year, month + 1, 0).day;
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = _getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun

    // Calculate offset to start from Monday (if 1 is Mon)
    // If weekday is 1 (Mon), offset is 0. If 7 (Sun), offset is 6.
    final offset = firstWeekday - 1;

    final totalCells = daysInMonth + offset;
    final rows = (totalCells / 7).ceil();

    return Table(
      children: List.generate(rows, (rowIndex) {
        return TableRow(
          children: List.generate(7, (colIndex) {
            final index = rowIndex * 7 + colIndex;
            if (index < offset || index >= totalCells) {
              return const SizedBox(height: 40);
            }

            final day = index - offset + 1;
            final date = DateTime(_focusedDay.year, _focusedDay.month, day);
            final events = _getEventsForDay(date);
            final isSelected = isSameDay(_selectedDay, date);
            final isToday = isSameDay(DateTime.now(), date);

            return TableCell(
              child: GestureDetector(
                onTap: () => _onDaySelected(date, _focusedDay),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : isToday
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                          fontWeight: isToday || isSelected
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                      if (events.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildEventList() {
    final events = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No sessions for this day'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final consultation = events[index];
        return ListTile(
          onTap: () {
            // Validate UUID before navigation
            try {
              final path = pathToFunction(RoutePaths.patientDetail)({
                'patientId': consultation.patientId,
              });
              context.push(path);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Invalid patient ID: ${consultation.patientId}'),
                ),
              );
            }
          },
          leading: CircleAvatar(
            child: Text(consultation.patientName[0]),
          ),
          title: Text(
            consultation.patientName,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Text(
            '${DateFormat.jm().format(consultation.scheduledTime)} - ${_getStatusLabel(consultation.appointmentStatus)}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (consultation.isScheduled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 10,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Scheduled',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              Chip(
                label: Text(
                  _getStatusLabel(consultation.appointmentStatus),
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: _getStatusColor(
                  context,
                  consultation.appointmentStatus,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(BuildContext context, AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.completed:
        return Colors.green.withOpacity(0.2);
      case AppointmentStatus.inProgress:
        return Colors.blue.withOpacity(0.2);
      case AppointmentStatus.cancelled:
        return Colors.red.withOpacity(0.2);
      case AppointmentStatus.upcoming:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  String _getStatusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.upcoming:
        return 'Upcoming';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.inProgress:
        return 'In Progress';
    }
  }
}
