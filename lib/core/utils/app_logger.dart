import 'package:logger/logger.dart' as logger_pkg;

class AppLogger {
  AppLogger()
    : _logger = logger_pkg.Logger(
        printer: logger_pkg.SimplePrinter(printTime: true),
      );

  final logger_pkg.Logger _logger;

  static const _redactedKeys = {
    'password',
    'otp',
    'token',
    'access_token',
    'refresh_token',
    'authorization',
    'authorization_code',
    'cloudinary_signature',
    'signature',
    'latitude',
    'longitude',
  };

  void debug(String event, [Map<String, Object?>? meta]) =>
      _logger.d({'event': event, ...?_sanitize(meta)});

  void info(String event, [Map<String, Object?>? meta]) =>
      _logger.i({'event': event, ...?_sanitize(meta)});

  void warn(String event, [Map<String, Object?>? meta]) =>
      _logger.w({'event': event, ...?_sanitize(meta)});

  void error(String event, [Map<String, Object?>? meta, Object? error]) =>
      _logger.e({'event': event, ...?_sanitize(meta)}, error: error);

  Map<String, Object?>? _sanitize(Map<String, Object?>? meta) {
    if (meta == null) return null;

    return meta.map((key, value) {
      final shouldRedact = _redactedKeys.any(
        (redacted) => key.toLowerCase().contains(redacted),
      );
      return MapEntry(key, shouldRedact ? '[REDACTED]' : value);
    });
  }
}

final appLogger = AppLogger();
