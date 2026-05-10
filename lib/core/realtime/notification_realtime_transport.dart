import 'dart:async';

abstract interface class NotificationRealtimeTransport {
  Future<void> connect({
    required void Function() onCounterChanged,
    required void Function() onNotificationChanged,
    required String userId,
  });

  Future<void> dispose();
}

class NotificationRealtimeBackoff {
  static const schedule = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  int _attempt = 0;

  Duration next() {
    final index = _attempt.clamp(0, schedule.length - 1);
    _attempt++;
    return schedule[index];
  }

  void reset() {
    _attempt = 0;
  }
}
