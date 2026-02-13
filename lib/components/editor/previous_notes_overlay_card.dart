import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saber/data/models/previous_session_note.dart';

/// Draggable overlay card for viewing previous session handwritten notes
class PreviousNotesOverlayCard extends StatefulWidget {
  final List<PreviousSessionNote> notes;
  final VoidCallback? onClose;

  const PreviousNotesOverlayCard({
    super.key,
    required this.notes,
    this.onClose,
  });

  @override
  State<PreviousNotesOverlayCard> createState() =>
      _PreviousNotesOverlayCardState();
}

class _PreviousNotesOverlayCardState extends State<PreviousNotesOverlayCard> {
  // Index of the currently viewed note (0 = most recent)
  var _currentIndex = 0;

  void _showNewerNote() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _showOlderNote() {
    if (_currentIndex < widget.notes.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notes.isEmpty) return const SizedBox.shrink();

    final currentNote = widget.notes[_currentIndex];
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Container(
      width: 400,
      height: 550,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.purple.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_edu,
                      size: 18,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session ${currentNote.sessionNumber}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                        ),
                        Text(
                          dateFormat.format(currentNote.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Navigation and Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image Viewer
                  InteractiveViewer(
                    clipBehavior: Clip.none,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.network(
                        currentNote.imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: Colors.purple,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load note',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Navigation Controls Overlay (Side buttons)
                  if (_currentIndex < widget.notes.length - 1)
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _NavButton(
                          icon: Icons.chevron_left,
                          onPressed: _showOlderNote,
                          tooltip: 'Older Session',
                        ),
                      ),
                    ),
                  if (_currentIndex > 0)
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _NavButton(
                          icon: Icons.chevron_right,
                          onPressed: _showNewerNote,
                          tooltip: 'Newer Session',
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Footer / Timeline indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(widget.notes.length, (index) {
                    final isCurrent = index == _currentIndex;
                    return Container(
                      width: isCurrent ? 12 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Colors.purple
                            : Colors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }).reversed,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _NavButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.3),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
