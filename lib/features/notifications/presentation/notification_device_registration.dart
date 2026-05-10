import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/notification_models.dart';
import 'notification_controller.dart';

final notificationDeviceRegistrationProvider = Provider<void>((ref) {
  if (kIsWeb || Firebase.apps.isEmpty) return;

  final registrar = _NotificationDeviceRegistrar(ref);
  unawaited(registrar.registerCurrentToken());

  final authSubscription = Supabase.instance.client.auth.onAuthStateChange
      .listen((event) {
        if (event.session != null) {
          unawaited(registrar.registerCurrentToken());
        }
      });

  final tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
    token,
  ) {
    unawaited(registrar.registerToken(token));
  });

  ref.onDispose(() {
    unawaited(authSubscription.cancel());
    unawaited(tokenSubscription.cancel());
  });
});

class _NotificationDeviceRegistrar {
  const _NotificationDeviceRegistrar(this.ref);

  final Ref ref;

  Future<void> registerCurrentToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        appLogger.info('notification_permission_denied');
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.trim().isEmpty) return;
      await registerToken(token);
    } catch (error) {
      appLogger.warn('notification_device_registration_failed', {
        'error': error.toString(),
      });
    }
  }

  Future<void> registerToken(String token) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || token.trim().isEmpty) return;

    try {
      await ref
          .read(notificationRepositoryProvider)
          .registerDevice(
            NotificationDeviceRegistration(
              locale: PlatformDispatcher.instance.locale.toLanguageTag(),
              platform: _platformName(),
              token: token,
              timezone: DateTime.now().timeZoneName,
            ),
          );
      appLogger.info('notification_device_registered');
    } catch (error) {
      appLogger.warn('notification_device_registration_failed', {
        'error': error.toString(),
      });
    }
  }

  String _platformName() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'web',
    };
  }
}
