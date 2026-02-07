import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:saber/data/prefs.dart';

class WelcomeHeader extends StatefulWidget {
  final String doctorName;
  final String? avatarUrl;

  const WelcomeHeader({super.key, required this.doctorName, this.avatarUrl});

  @override
  State<WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<WelcomeHeader> {
  Battery? _battery;
  var _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    try {
      _battery = Battery();
      _updateBattery();

      _batterySubscription = _battery?.onBatteryStateChanged.listen((state) {
        if (mounted) {
          setState(() => _batteryState = state);
          _updateBattery();
        }
      });
    } catch (e) {
      debugPrint('Error initializing battery service: $e');
    }

    // Update time every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });

    stows.isOnline.addListener(_onConnectivityChanged);
  }

  Future<void> _updateBattery() async {
    try {
      if (_battery == null) return;
      final level = await _battery!.batteryLevel;
      if (mounted) {
        setState(() => _batteryLevel = level);
      }
    } catch (e) {
      debugPrint('Error getting battery level: $e');
    }
  }

  void _onConnectivityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    _timer?.cancel();
    stows.isOnline.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  bool get _isOnline => stows.isOnline.value;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);
    final timeStr = DateFormat('h:mm a').format(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Always show user avatar on the left
        if (widget.avatarUrl != null)
          CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(widget.avatarUrl!),
          )
        else
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),

        const SizedBox(width: 16),

        // 2. Greeting and Name in the middle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                    ? (stows.userRole.value == 'doctor' &&
                              !widget.doctorName.toLowerCase().startsWith('dr.')
                          ? 'Dr. ${widget.doctorName}'
                          : widget.doctorName)
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

        const SizedBox(width: 16),

        // 3. Right side: Status, Time, and Battery
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAIPulse(context),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '•',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      fontSize: 10,
                    ),
                  ),
                ),
                _buildBatteryIndicator(),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBatteryIndicator() {
    IconData iconData;
    if (_batteryState == BatteryState.charging) {
      iconData = Icons.battery_charging_full;
    } else {
      if (_batteryLevel > 90) {
        iconData = Icons.battery_full;
      } else if (_batteryLevel > 70) {
        iconData = Icons.battery_6_bar;
      } else if (_batteryLevel > 50) {
        iconData = Icons.battery_4_bar;
      } else if (_batteryLevel > 30) {
        iconData = Icons.battery_2_bar;
      } else {
        iconData = Icons.battery_alert;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          iconData,
          size: 14,
          color: _batteryLevel < 20
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          '$_batteryLevel%',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
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
    final statusText = isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
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
