class AppConfig {
  const AppConfig._();

  static const appName = 'Urban Parking';
  static const appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: String.fromEnvironment(
      'EXPO_PUBLIC_APP_ENV',
      defaultValue: 'development',
    ),
  );
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'EXPO_PUBLIC_API_BASE_URL',
      defaultValue: 'https://flowaux.in/api/v1',
    ),
  );
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: String.fromEnvironment('EXPO_PUBLIC_SUPABASE_URL'),
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment('EXPO_PUBLIC_SUPABASE_ANON_KEY'),
  );
  static const authRedirectScheme = String.fromEnvironment(
    'AUTH_REDIRECT_SCHEME',
    defaultValue: String.fromEnvironment(
      'EXPO_PUBLIC_AUTH_REDIRECT_SCHEME',
      defaultValue: 'urbanparking',
    ),
  );
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: String.fromEnvironment('EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID'),
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: String.fromEnvironment('EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID'),
  );
  static const cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: String.fromEnvironment('EXPO_PUBLIC_CLOUDINARY_CLOUD_NAME'),
  );
  static const cloudinaryUploadFolder = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_FOLDER',
    defaultValue: String.fromEnvironment(
      'EXPO_PUBLIC_CLOUDINARY_UPLOAD_FOLDER',
      defaultValue: 'urban-parking/listing-photos',
    ),
  );

  static const requestTimeout = Duration(seconds: 15);
  static const geoCacheBoxName = 'geo_discovery_cache_v1';
  static const authSessionStorageKey = 'urban_parking.auth.session';

  static bool get isProduction => appEnv == 'production';
  static String get apiBaseHost =>
      Uri.tryParse(apiBaseUrl)?.host.toLowerCase() ?? 'invalid-api-host';
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static String get geoRuntimeMode => useMockGeoData ? 'mock' : 'network';
  static bool get useMockGeoData =>
      const bool.fromEnvironment(
        'USE_MOCK_GEO',
        defaultValue: bool.fromEnvironment(
          'EXPO_PUBLIC_USE_MOCK_GEO',
          defaultValue: false,
        ),
      ) &&
      !isProduction;
}
