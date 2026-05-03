import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'config/app_router.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/telemetry.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  telemetry.event(TelemetryEvent.appBootStarted);

  await Hive.initFlutter();
  await Hive.openBox<String>(AppConfig.geoCacheBoxName);

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

  runApp(const ProviderScope(child: UrbanParkingApp()));
}

class UrbanParkingApp extends ConsumerWidget {
  const UrbanParkingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
