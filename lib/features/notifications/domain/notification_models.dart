enum NotificationCategory {
  message,
  booking,
  payment,
  security,
  admin,
  system,
  marketing;

  String get apiValue => name;

  static NotificationCategory fromJson(Object? value) {
    return NotificationCategory.values.firstWhere(
      (category) => category.name == value?.toString(),
      orElse: () => NotificationCategory.system,
    );
  }
}

enum NotificationPriority {
  low,
  normal,
  high,
  critical;

  static NotificationPriority fromJson(Object? value) {
    return NotificationPriority.values.firstWhere(
      (priority) => priority.name == value?.toString(),
      orElse: () => NotificationPriority.normal,
    );
  }
}

enum NotificationStatus {
  unread,
  read,
  dismissed,
  archived;

  static NotificationStatus fromJson(Object? value) {
    return NotificationStatus.values.firstWhere(
      (status) => status.name == value?.toString(),
      orElse: () => NotificationStatus.unread,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.body,
    required this.category,
    required this.createdAt,
    required this.cursor,
    required this.id,
    required this.priority,
    required this.status,
    required this.title,
    this.deeplink,
    this.payload = const {},
    this.readAt,
  });

  final String body;
  final NotificationCategory category;
  final DateTime createdAt;
  final String cursor;
  final String? deeplink;
  final String id;
  final Map<String, Object?> payload;
  final NotificationPriority priority;
  final DateTime? readAt;
  final NotificationStatus status;
  final String title;

  bool get isUnread => status == NotificationStatus.unread;

  static AppNotification fromJson(Object? json) {
    final map = Map<String, Object?>.from(json as Map);
    return AppNotification(
      body: _stringFrom(map, const ['body']) ?? '',
      category: NotificationCategory.fromJson(map['category']),
      createdAt:
          _dateTimeFrom(map, const ['createdAt', 'created_at']) ??
          DateTime.now(),
      cursor: _stringFrom(map, const ['cursor']) ?? '',
      deeplink: _stringFrom(map, const ['deeplink']),
      id: _stringFrom(map, const ['id']) ?? '',
      payload: _mapFrom(map['payload']),
      priority: NotificationPriority.fromJson(map['priority']),
      readAt: _dateTimeFrom(map, const ['readAt', 'read_at']),
      status: NotificationStatus.fromJson(map['status']),
      title: _stringFrom(map, const ['title']) ?? 'Lotzi update',
    );
  }
}

class NotificationFeedPage {
  const NotificationFeedPage({
    required this.items,
    required this.unreadByCategory,
  });

  final List<AppNotification> items;
  final Map<String, int> unreadByCategory;

  int get totalUnread => unreadByCategory['all'] ?? 0;

  String? get nextCursor => items.isEmpty ? null : items.last.cursor;

  static NotificationFeedPage fromJson(Object? json) {
    final map = json is Map ? Map<String, Object?>.from(json) : const {};
    final items = map['items'];
    final counters = map['unreadByCategory'] ?? map['unread_by_category'];
    return NotificationFeedPage(
      items: items is List
          ? items.map(AppNotification.fromJson).toList(growable: false)
          : const [],
      unreadByCategory: _intMapFrom(counters),
    );
  }
}

class NotificationPreference {
  const NotificationPreference({
    required this.category,
    required this.emailEnabled,
    required this.inAppEnabled,
    required this.pushEnabled,
    required this.quietHoursEnabled,
    required this.realtimeEnabled,
    required this.smsEnabled,
    required this.timezone,
    this.marketingConsentAt,
    this.quietHoursEndMinute,
    this.quietHoursStartMinute,
  });

  final NotificationCategory category;
  final bool emailEnabled;
  final bool inAppEnabled;
  final DateTime? marketingConsentAt;
  final bool pushEnabled;
  final bool quietHoursEnabled;
  final int? quietHoursEndMinute;
  final int? quietHoursStartMinute;
  final bool realtimeEnabled;
  final bool smsEnabled;
  final String timezone;

  static NotificationPreference fromJson(Object? json) {
    final map = Map<String, Object?>.from(json as Map);
    return NotificationPreference(
      category: NotificationCategory.fromJson(map['category']),
      emailEnabled: _boolFrom(map, const ['emailEnabled', 'email_enabled']),
      inAppEnabled: _boolFrom(map, const ['inAppEnabled', 'in_app_enabled']),
      marketingConsentAt: _dateTimeFrom(map, const [
        'marketingConsentAt',
        'marketing_consent_at',
      ]),
      pushEnabled: _boolFrom(map, const ['pushEnabled', 'push_enabled']),
      quietHoursEnabled: _boolFrom(map, const [
        'quietHoursEnabled',
        'quiet_hours_enabled',
      ]),
      quietHoursEndMinute: _nullableIntFrom(map, const [
        'quietHoursEndMinute',
        'quiet_hours_end_minute',
      ]),
      quietHoursStartMinute: _nullableIntFrom(map, const [
        'quietHoursStartMinute',
        'quiet_hours_start_minute',
      ]),
      realtimeEnabled: _boolFrom(map, const [
        'realtimeEnabled',
        'realtime_enabled',
      ]),
      smsEnabled: _boolFrom(map, const ['smsEnabled', 'sms_enabled']),
      timezone: _stringFrom(map, const ['timezone']) ?? 'Asia/Kolkata',
    );
  }
}

class NotificationPreferenceUpdate {
  const NotificationPreferenceUpdate({
    required this.category,
    this.emailEnabled,
    this.inAppEnabled,
    this.marketingConsent,
    this.pushEnabled,
    this.quietHoursEnabled,
    this.quietHoursEndMinute,
    this.quietHoursStartMinute,
    this.realtimeEnabled,
    this.smsEnabled,
    this.timezone,
  });

  final NotificationCategory category;
  final bool? emailEnabled;
  final bool? inAppEnabled;
  final bool? marketingConsent;
  final bool? pushEnabled;
  final bool? quietHoursEnabled;
  final int? quietHoursEndMinute;
  final int? quietHoursStartMinute;
  final bool? realtimeEnabled;
  final bool? smsEnabled;
  final String? timezone;

  Map<String, Object?> toJson() => {
    'category': category.apiValue,
    'emailEnabled': emailEnabled,
    'inAppEnabled': inAppEnabled,
    'marketingConsent': marketingConsent,
    'pushEnabled': pushEnabled,
    'quietHoursEnabled': quietHoursEnabled,
    'quietHoursEndMinute': quietHoursEndMinute,
    'quietHoursStartMinute': quietHoursStartMinute,
    'realtimeEnabled': realtimeEnabled,
    'smsEnabled': smsEnabled,
    'timezone': timezone,
  }..removeWhere((_, value) => value == null);
}

class NotificationDeviceRegistration {
  const NotificationDeviceRegistration({
    required this.platform,
    required this.token,
    this.appVersion,
    this.locale,
    this.provider = 'fcm',
    this.timezone = 'Asia/Kolkata',
  });

  final String? appVersion;
  final String? locale;
  final String platform;
  final String provider;
  final String timezone;
  final String token;

  Map<String, Object?> toJson() => {
    'appVersion': appVersion,
    'locale': locale,
    'platform': platform,
    'provider': provider,
    'timezone': timezone,
    'token': token,
  }..removeWhere((_, value) => value == null);
}

String? _stringFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

bool _boolFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
  }
  return false;
}

int? _nullableIntFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

DateTime? _dateTimeFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

Map<String, Object?> _mapFrom(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  return const {};
}

Map<String, int> _intMapFrom(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, raw) {
    if (raw is num) return MapEntry(key.toString(), raw.toInt());
    return MapEntry(key.toString(), int.tryParse(raw.toString()) ?? 0);
  });
}
