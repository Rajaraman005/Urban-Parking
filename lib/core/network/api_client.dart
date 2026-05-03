import 'dart:async';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../errors/app_failure.dart';

typedef AccessTokenReader = FutureOr<String?> Function();

class ApiClient {
  ApiClient({Dio? dio, AccessTokenReader? accessTokenReader})
    : _accessTokenReader = accessTokenReader,
      dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.requestTimeout,
              receiveTimeout: AppConfig.requestTimeout,
              sendTimeout: AppConfig.requestTimeout,
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ),
          ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _accessTokenReader?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final AccessTokenReader? _accessTokenReader;

  static NetworkFailure toFailure(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      final details = data is Map<String, Object?> ? data : const {};
      final code = details['code']?.toString();
      final message =
          details['message']?.toString() ?? error.message ?? 'Network error';

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          status == 408 ||
          status == 504) {
        return NetworkFailure(message, code: 'backend_timeout');
      }
      if (status == 429) {
        return NetworkFailure(message, code: 'rate_limited');
      }
      if (code != null) {
        return NetworkFailure(message, code: code);
      }
      return NetworkFailure(message, code: status?.toString());
    }

    return NetworkFailure(
      error is AppFailure ? error.message : 'Something went wrong',
      code: error is AppFailure ? error.code : 'unknown',
    );
  }
}
