import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class HandwritingField extends StatefulWidget {
  final String label;
  final String? initialImageUrl;
  final SignatureController controller;
  final bool readOnly;
  final double height;

  const HandwritingField({
    super.key,
    required this.label,
    this.initialImageUrl,
    required this.controller,
    this.readOnly = false,
    this.height = 150,
  });

  @override
  State<HandwritingField> createState() => _HandwritingFieldState();
}

class _HandwritingFieldState extends State<HandwritingField> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.readOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.fullscreen, size: 20),
                    onPressed: () => _showFullScreenEditor(context),
                    tooltip: 'Expand',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () => widget.controller.clear(),
                    tooltip: 'Clear',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onDoubleTap: widget.readOnly
              ? null
              : () => _showFullScreenEditor(context),
          child: Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
              color: widget.readOnly
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                  : Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.readOnly
                  ? _buildReadOnlyView()
                  : Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: RepaintBoundary(
                          child: Signature(
                            controller: widget.controller,
                            backgroundColor: Colors.white,
                            width: 1200,
                            height: 800,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreenEditor(BuildContext context) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(widget.label),
                actions: [
                  TextButton.icon(
                    onPressed: () => widget.controller.clear(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: Container(
                color: Colors.grey[100],
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 1200 / 800,
                      child: RepaintBoundary(
                        child: Signature(
                          controller: widget.controller,
                          backgroundColor: Colors.white,
                          width: 1200,
                          height: 800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  Widget _buildReadOnlyView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.initialImageUrl != null) {
      return Image.network(
        widget.initialImageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loading) {
          if (loading == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (context, error, stack) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    }

    if (widget.controller.isNotEmpty) {
      // This case is rare if we're truly readOnly, but good for preview
      return Signature(
        controller: widget.controller,
        backgroundColor: Colors.transparent,
      );
    }

    return Center(
      child: Text(
        'No content',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }
}
