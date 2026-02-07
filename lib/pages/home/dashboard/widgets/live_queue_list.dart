import 'package:flutter/material.dart';
import 'package:saber/data/models/dashboard_models.dart';

class LiveQueueList extends StatelessWidget {
  final List<QueueItem> queue;
  final Function(QueueItem) onStartSession;
  final Function(QueueItem)? onCancel;
  final Function(int, int)? onReorder;

  const LiveQueueList({
    super.key,
    required this.queue,
    required this.onStartSession,
    this.onCancel,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Live Queue',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
        else if (queue.isEmpty)
          _buildEmptyState(context)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Theme(
                data: theme.copyWith(
                  canvasColor:
                      Colors.transparent, // Fix for ghosting during drag
                ),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(0),
                  itemCount: queue.length,
                  onReorder: onReorder ?? (oldIndex, newIndex) {},
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    return Column(
                      key: ValueKey(item.id),
                      children: [
                        _buildQueueItem(context, item, index),
                        if (index < queue.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.outlineVariant.withOpacity(
                              0.2,
                            ),
                          ),
                      ],
                    );
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 8,
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    );
                  },
                ),
              ),
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
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueItem(BuildContext context, QueueItem item, int index) {
    final theme = Theme.of(context);

    // Determine status color
    Color statusColor;
    switch (item.status.toLowerCase()) {
      case 'in consultation':
      case 'in_progress':
        statusColor = Colors.green;
      case 'in vitals':
        statusColor = Colors.orange;
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
                '${index + 1}',
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
                      Flexible(
                        child: Text(
                          item.patientName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ID Pill
                      Text(
                        '${item.age} yrs',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildGenderTag(item.gender, theme),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Builder(
                          builder: (context) {
                            final duration = DateTime.now().difference(
                              item.registeredTime,
                            );
                            final hours = duration.inHours;
                            final minutes = duration.inMinutes.remainder(60);
                            final timeString = hours > 0
                                ? '${hours}h ${minutes}m'
                                : '${minutes}m';
                            return Text(
                              '$timeString waited',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  item.patientType,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Action button (Start or arrow)
            // Action button (Start)
            if (item.status.toLowerCase() != 'in consultation' &&
                item.status.toLowerCase() != 'in_progress')
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded),
                color: theme.colorScheme.primary,
                onPressed: () => onStartSession(item),
                tooltip: 'Start Session',
              ),

            // More options (Cancel)
            if (onCancel != null)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                        Icon(
                          Icons.cancel_outlined,
                          color: Colors.red,
                          size: 20,
                        ),
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

  Widget _buildGenderTag(String gender, ThemeData theme) {
    final lowerGender = gender.toLowerCase().trim();
    Color backgroundColor;
    Color textColor;

    if (lowerGender == 'male' || lowerGender == 'm') {
      backgroundColor = Colors.blue.withValues(alpha: 0.1);
      textColor = Colors.blue.shade700;
    } else if (lowerGender == 'female' || lowerGender == 'f') {
      backgroundColor = Colors.pink.withValues(alpha: 0.1);
      textColor = Colors.pink.shade700;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        gender,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
