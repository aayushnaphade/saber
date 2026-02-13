import 'package:flutter/material.dart';

class SaberAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final IconData fallbackIcon;
  final Color? backgroundColor;

  const SaberAvatar({
    super.key,
    this.url,
    this.radius = 28,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _buildFallback(context);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
      child: ClipOval(
        child: Image.network(
          url!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('SaberAvatar: Error loading image $url: $error');
            return _buildFallbackContent(context);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
      child: _buildFallbackContent(context),
    );
  }

  Widget _buildFallbackContent(BuildContext context) {
    return Icon(
      fallbackIcon,
      size: radius,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }
}
