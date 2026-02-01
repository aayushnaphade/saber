import 'package:flutter/material.dart';
import 'package:saber/data/models/dashboard_models.dart';

class LiveQueueList extends StatelessWidget {
  final List<QueueItem> queue;
  final Function(QueueItem) onStartSession;
  final Function(QueueItem)? onCancel;

  const LiveQueueList({
    super.key,
    required this.queue,
    required this.onStartSession,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter out the current patient if they are already displayed in the main card?
    // The user said "replace the section of today's schedule with the live Queue".
    // Usually the main LiveQueueCard shows the *current* patient (top of queue).
    // This list should probably show *all* or *waiting* patients.
    // Based on dashboard_page.dart, `_queue` contains everyone.
    // `LiveQueueCard` shows `waitingCount` and `currentPatient` (first one).
    // If we duplicate the first patient here it might be redundant, but a list usually shows everyone.
    // Let's show the whole queue for now, or maybe skip the first one if it's "in progress"?
    // The requirement says "replace the section of today's schedule with the live Queue".
    // I will display the full list for clarity, or maybe just the waiting ones.
    // Let's stick to displaying the provided list.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Queue',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${queue.length} Active',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (queue.isEmpty)
          _buildEmptyState(context)
        else
          Container(
            height: 400, // Fixed height to show approx 5 items (approx 70-80px each)
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(0),
              itemCount: queue.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withOpacity(0.2),
              ),
              itemBuilder: (context, index) {
                final item = queue[index];
                return _buildQueueItem(context, item, index);
              },
            ),
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
              Icons.people_outline,
              size: 48,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Queue is empty',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'New patients will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueItem(BuildContext context, QueueItem item, int index) {
    final theme = Theme.of(context);
    final isFirst = index == 0;
    
    // Determine status color
    Color statusColor;
    switch (item.status.toLowerCase()) {
      case 'in consultation':
      case 'in_progress':
        statusColor = Colors.green;
        break;
      case 'in vitals':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.blue;
    }

    return InkWell(
      onTap: () => onStartSession(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              child: Text(
                item.patientName.isNotEmpty ? item.patientName[0] : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.patientName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ID Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.patientId,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time, 
                        size: 14, 
                        color: theme.colorScheme.onSurfaceVariant
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.estimatedWaitTime.inMinutes > 0
                            ? '${item.estimatedWaitTime.inMinutes} min wait'
                            : 'Ready now',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withOpacity(0.2),
                ),
              ),
              child: Text(
                item.status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Action button (Start or arrow)
            // Action button (Start)
            if (item.status.toLowerCase() != 'in consultation' && item.status.toLowerCase() != 'in_progress')
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded),
                color: theme.colorScheme.primary,
                onPressed: () => onStartSession(item),
                tooltip: 'Start Session',
              ),
            
            // More options (Cancel)
            if (onCancel != null)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                onSelected: (value) {
                  if (value == 'cancel') {
                    onCancel!(item);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Cancel', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
