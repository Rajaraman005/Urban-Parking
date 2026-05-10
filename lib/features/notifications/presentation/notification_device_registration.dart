import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/notification_models.dart';
import 'notification_controller.dart';

final notificationDeviceRegistrationProvider = Provider<void>((ref) {
  if (kIsWeb || Firebase.apps.isEmpty) return;

  final registrar = _NotificationDeviceRegistrar(ref);
  unawaited(registrar.registerCurrentToken(reason: 'startup'));

  var retryCount = 0;
  final retryTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
    retryCount += 1;
    if (retryCount > 24) {
      timer.cancel();
      return;
    }
    unawaited(registrar.registerCurrentToken(reason: 'startup_retry'));
  });

  final lifecycleListener = AppLifecycleListener(
    onResume: () =>
        unawaited(registrar.registerCurrentToken(reason: 'app_resume')),
  );

  final authSubscription = Supabase.instance.client.auth.onAuthStateChange
      .listen((event) {
        if (event.session != null) {
          unawaited(registrar.registerCurrentToken(reason: 'auth_change'));
        }
      });

  final tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
    token,
  ) {
    unawaited(registrar.registerToken(token));
  });

  ref.onDispose(() {
    retryTimer.cancel();
    lifecycleListener.dispose();
    unawaited(authSubscription.cancel());
    unawaited(tokenSubscription.cancel());
  });
});

class _NotificationDeviceRegistrar {
  const _NotificationDeviceRegistrar(this.ref);

  final Ref ref;

  Future<void> registerCurrentToken({required String reason}) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      appLogger.debug('notification_device_registration_waiting_for_session', {
        'reason': reason,
      });
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      appLogger.debug('notification_device_registration_started', {
        'reason': reason,
      });
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
        appLogger.info('notification_permission_denied', {'reason': reason});
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        appLogger.warn('notification_device_token_unavailable', {
          'authorizationStatus': settings.authorizationStatus.name,
          'reason': reason,
        });
        return;
      }
      await registerToken(token, reason: reason);
    } catch (error) {
      appLogger.warn('notification_device_registration_failed', {
        'error': error.toString(),
        'reason': reason,
      });
    }
  }

  Future<void> registerToken(
    String token, {
    String reason = 'token_refresh',
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || token.trim().isEmpty) {
      appLogger.debug('notification_device_registration_skipped', {
        'hasSession': session != null,
        'hasToken': token.trim().isNotEmpty,
        'reason': reason,
      });
      return;
    }

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
      appLogger.info('notification_device_registered', {'reason': reason});
    } catch (error) {
      appLogger.warn('notification_device_registration_failed', {
        'error': error.toString(),
        'reason': reason,
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
