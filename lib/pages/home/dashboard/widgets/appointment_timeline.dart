import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saber/data/models/dashboard_models.dart';

class AppointmentTimeline extends StatelessWidget {
  final List<Appointment> appointments;
  final Function(String) onCancel;
  final Function(String, DateTime) onReschedule;

  const AppointmentTimeline({
    super.key,
    required this.appointments,
    required this.onCancel,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Schedule',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('View Calendar')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (appointments.isEmpty)
          _buildEmptyState(context)
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appointment = appointments[index];
              final isLast = index == appointments.length - 1;
              return _buildTimelineItem(context, appointment, isLast);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.event_available,
              size: 48,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No appointments today',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    Appointment appointment,
    bool isLast,
  ) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('h:mm a');
    final isPast = appointment.status == AppointmentStatus.completed;
    final isNow = appointment.status == AppointmentStatus.inProgress;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                timeFormat.format(appointment.time),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isNow
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Timeline Line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isNow
                      ? theme.colorScheme.primary
                      : isPast
                      ? theme.colorScheme.outline
                      : theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isNow
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isNow
                      ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isNow
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isNow
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: isNow
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                      child: Text(appointment.patientName[0]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  appointment.patientName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (appointment.isScheduled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 12,
                                        color: theme.colorScheme.onSecondaryContainer,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Scheduled',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            appointment.reason,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusChip(context, appointment.status),
                        if (appointment.status == AppointmentStatus.upcoming)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            onSelected: (value) {
                              if (value == 'cancel') {
                                onCancel(appointment.id);
                              } else if (value == 'reschedule') {
                                showDatePicker(
                                  context: context,
                                  initialDate: appointment.time,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                ).then((date) {
                                  if (date != null && context.mounted) {
                                    showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                          appointment.time),
                                    ).then((time) {
                                      if (time != null) {
                                        final newDateTime = DateTime(
                                          date.year,
                                          date.month,
                                          date.day,
                                          time.hour,
                                          time.minute,
                                        );
                                        onReschedule(
                                            appointment.id, newDateTime);
                                      }
                                    });
                                  }
                                });
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'reschedule',
                                child: Row(
                                  children: [
                                    Icon(Icons.schedule, size: 20),
                                    SizedBox(width: 8),
                                    Text('Reschedule'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'cancel',
                                child: Row(
                                  children: [
                                    Icon(Icons.cancel_outlined,
                                        size: 20, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Cancel',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, AppointmentStatus status) {
    Color color;
    String label;

    switch (status) {
      case AppointmentStatus.upcoming:
        color = Colors.blue;
        label = 'Upcoming';
      case AppointmentStatus.inProgress:
        color = Colors.green;
        label = 'Now';
      case AppointmentStatus.completed:
        color = Colors.grey;
        label = 'Done';
      case AppointmentStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
