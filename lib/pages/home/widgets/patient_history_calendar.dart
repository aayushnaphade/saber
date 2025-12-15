import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_to_regexp/path_to_regexp.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/routes.dart';

class PatientHistoryCalendar extends StatefulWidget {
  const PatientHistoryCalendar({super.key});

  @override
  State<PatientHistoryCalendar> createState() => _PatientHistoryCalendarState();
}

class _PatientHistoryCalendarState extends State<PatientHistoryCalendar> {
  var _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late final Map<DateTime, List<Appointment>> _events;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _events = _generateMockEvents();
  }

  Map<DateTime, List<Appointment>> _generateMockEvents() {
    final events = <DateTime, List<Appointment>>{};
    final now = DateTime.now();

    // Generate some random appointments for the current month and previous month
    for (var i = 0; i < 10; i++) {
      final date = now.subtract(Duration(days: i * 2));
      final dateKey = DateTime(date.year, date.month, date.day);

      events[dateKey] = [
        Appointment(
          id: 'apt_$i',
          patientName: 'Patient $i',
          patientId: 'p_$i',
          time: date.add(Duration(hours: 9 + (i % 5))),
          reason: 'Follow-up',
          status: AppointmentStatus.completed,
        ),
        if (i % 3 == 0)
          Appointment(
            id: 'apt_${i}_2',
            patientName: 'Patient ${i}B',
            patientId: 'p_${i}b',
            time: date.add(const Duration(hours: 14)),
            reason: 'Consultation',
            status: AppointmentStatus.completed,
          ),
      ];
    }
    return events;
  }

  List<Appointment> _getEventsForDay(DateTime day) {
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
      child: Column(
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
        child: Text('No history for this day'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          onTap: () {
            final path = pathToFunction(RoutePaths.patientDetail)({
              'patientId': event.patientId,
            });
            context.push(path);
          },
          leading: CircleAvatar(child: Text(event.patientName[0])),
          title: Text(
            event.patientName,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Text(
            '${DateFormat.jm().format(event.time)} - ${event.reason}',
          ),
          trailing: Chip(
            label: Text(
              _getStatusLabel(event.status),
              style: const TextStyle(fontSize: 10),
            ),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        );
      },
    );
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
