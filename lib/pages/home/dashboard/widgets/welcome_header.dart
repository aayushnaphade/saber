import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/supabase/supabase_client.dart';

class WelcomeHeader extends StatefulWidget {
  final String doctorName;
  final String? avatarUrl;

  const WelcomeHeader({super.key, required this.doctorName, this.avatarUrl});

  @override
  State<WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<WelcomeHeader> {
  bool _isOnline = true;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // Check connectivity every 10 seconds
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      // Try to ping Supabase to check connectivity
      final response = await supabase
          .from('profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      
      if (mounted) {
        setState(() {
          _isOnline = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOnline = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Image.asset(
            'assets/android/playstore-icon.png',
            width: 32,
            height: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$greeting,',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
              Text(
                widget.doctorName.isNotEmpty 
                  ? (stows.userRole.value == 'doctor' ? 'Dr. ${widget.doctorName}' : widget.doctorName)
                  : (stows.userRole.value == 'doctor' ? 'Doctor' : 'User'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        if (widget.avatarUrl != null) ...[
          CircleAvatar(radius: 24, backgroundImage: NetworkImage(widget.avatarUrl!)),
          const SizedBox(width: 16),
        ],
        _buildAIPulse(context),
      ],
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildAIPulse(BuildContext context) {
    final isOnline = _isOnline;
    final statusColor = isOnline 
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    final statusText = isOnline ? 'Synapsai Active' : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline 
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
            : Theme.of(context).colorScheme.errorContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: isOnline ? [
                BoxShadow(
                  color: statusColor.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ] : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isOnline 
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
