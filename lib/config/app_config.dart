class AppConfig {
  const AppConfig._();

  static const _defaultApiBaseUrl = 'https://lotzi.in/api/v1';
  static const _legacyApiHosts = {
    'flowaux.in': 'lotzi.in',
    'www.flowaux.in': 'www.lotzi.in',
  };

  static const appName = 'Lotzi';
  static const appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: String.fromEnvironment(
      'EXPO_PUBLIC_APP_ENV',
      defaultValue: 'development',
    ),
  );
  static const _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'EXPO_PUBLIC_API_BASE_URL',
      defaultValue: _defaultApiBaseUrl,
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
      defaultValue: 'lotzi/listing-photos',
    ),
  );

  static const requestTimeout = Duration(seconds: 15);
  static const geoCacheBoxName = 'geo_discovery_cache_v1';
  static const authSessionStorageKey = 'urban_parking.auth.session';

  static String get apiBaseUrl => _normalizeApiBaseUrl(_rawApiBaseUrl);
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

  static String _normalizeApiBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return _defaultApiBaseUrl;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return trimmed;

    final replacementHost = _legacyApiHosts[uri.host.toLowerCase()];
    if (replacementHost == null) return trimmed;

    return uri.replace(host: replacementHost).toString();
  }
}
