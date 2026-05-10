import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import 'notification_controller.dart';

const lotziNotificationChannelId = 'lotzi_high_importance_v1';

final notificationForegroundPresentationProvider = Provider<void>((ref) {
  if (kIsWeb || Firebase.apps.isEmpty) return;

  final presenter = NotificationForegroundPresenter.instance;
  unawaited(presenter.initialize());

  final messageSubscription = FirebaseMessaging.onMessage.listen((message) {
    unawaited(presenter.showRemoteMessage(message));
    ref.invalidate(notificationsProvider);
  });

  ref.onDispose(() {
    unawaited(messageSubscription.cancel());
  });
});

class NotificationForegroundPresenter {
  NotificationForegroundPresenter._();

  static final instance = NotificationForegroundPresenter._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Set<String> _shownKeys = <String>{};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
        defaultPresentSound: true,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          lotziNotificationChannelId,
          'Lotzi notifications',
          description: 'Messages, bookings, and important Lotzi updates',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      await android?.requestNotificationsPermission();

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      _initialized = true;
      appLogger.info('notification_foreground_presenter_ready');
    } catch (error) {
      appLogger.warn('notification_foreground_presenter_failed', {
        'error': error.toString(),
      });
    }
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        _stringField(message.data, 'title') ??
        'Lotzi update';
    final body =
        message.notification?.body ?? _stringField(message.data, 'body') ?? '';
    final key =
        _stringField(message.data, 'notificationId') ??
        message.messageId ??
        '$title:$body:${DateTime.now().millisecondsSinceEpoch}';

    await show(
      key: key,
      title: title,
      body: body,
      payload: _stringField(message.data, 'deeplink'),
    );
  }

  Future<void> showNotificationRecord(Map<String, dynamic> record) async {
    await show(
      key: _stringField(record, 'id') ?? record.hashCode.toString(),
      title: _stringField(record, 'title') ?? 'Lotzi update',
      body: _stringField(record, 'body') ?? '',
      payload: _stringField(record, 'deeplink'),
    );
  }

  Future<void> show({
    required String key,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    if (!_initialized || title.trim().isEmpty) return;
    if (!_shownKeys.add(key)) return;

    if (_shownKeys.length > 100) {
      _shownKeys.remove(_shownKeys.first);
    }

    await _plugin.show(
      id: _notificationIdFor(key),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          lotziNotificationChannelId,
          'Lotzi notifications',
          channelDescription: 'Messages, bookings, and important Lotzi updates',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          playSound: true,
          enableVibration: true,
          ticker: 'Lotzi notification',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  int _notificationIdFor(String key) {
    var value = 0;
    for (final unit in key.codeUnits) {
      value = ((value * 31) + unit) & 0x7fffffff;
    }
    return value == 0 ? 1 : value;
  }

  String? _stringField(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
