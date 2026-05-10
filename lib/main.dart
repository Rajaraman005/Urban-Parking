import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'config/app_providers.dart';
import 'config/app_router.dart';
import 'config/preview_flags.dart';
import 'features/parking/presentation/owned_parking_live_sync.dart';
import 'features/profile/presentation/profile_live_sync.dart';
import 'features/messaging/presentation/messaging_realtime.dart';
import 'features/notifications/presentation/notification_device_registration.dart';
import 'features/notifications/presentation/notification_foreground_presenter.dart';
import 'features/notifications/presentation/notification_realtime.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/telemetry.dart';
import 'shared/widgets/app_loader.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  telemetry.event(TelemetryEvent.appBootStarted);

  await Hive.initFlutter();
  await Hive.openBox<String>(AppConfig.geoCacheBoxName);

  try {
    await Firebase.initializeApp();
    appLogger.info('firebase_initialized');
  } catch (error) {
    appLogger.warn('firebase_initialization_failed', {
      'error': error.toString(),
    });
  }

  appLogger.info('runtime_config_loaded', {
    'appEnv': AppConfig.appEnv,
    'apiBaseHost': AppConfig.apiBaseHost,
    'apiBaseUrlConfigured': AppConfig.apiBaseUrl.isNotEmpty,
    'geoRuntimeMode': AppConfig.geoRuntimeMode,
    'supabaseUrlConfigured': AppConfig.supabaseUrl.isNotEmpty,
    'supabaseAnonKeyConfigured': AppConfig.supabaseAnonKey.isNotEmpty,
    'googleWebClientConfigured': AppConfig.googleWebClientId.isNotEmpty,
    'cloudinaryConfigured': AppConfig.cloudinaryCloudName.isNotEmpty,
  });

  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } else {
    appLogger.warn('supabase_not_configured', {'appEnv': AppConfig.appEnv});
  }

  runApp(const ProviderScope(child: LotziApp()));
}

class LotziApp extends ConsumerWidget {
  const LotziApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (showLoaderPreview) {
      return MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        home: const Scaffold(
          backgroundColor: Color(0xFFF5F6F8),
          body: AppLoader(
            title: 'Lotzi',
            body: 'Preparing your parking experience',
          ),
        ),
      );
    }

    final router = ref.watch(appRouterProvider);
    ref.watch(ownedParkingLiveSyncProvider);
    ref.watch(profileLiveSyncProvider);
    ref.watch(messagingInboxLiveSyncProvider);
    ref.watch(notificationDeviceRegistrationProvider);
    ref.watch(notificationForegroundPresentationProvider);
    ref.watch(notificationLiveSyncProvider);
    ref.watch(locationWarmupProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
