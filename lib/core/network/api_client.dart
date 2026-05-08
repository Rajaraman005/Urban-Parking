import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../errors/app_failure.dart';

typedef AccessTokenReader = FutureOr<String?> Function();

class ApiClient {
  static const _uuid = Uuid();

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
          options.headers['X-Request-ID'] ??= _uuid.v4();
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

  static AppFailure toFailure(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      final details = data is Map<String, Object?> ? data : const {};
      final code = details['code']?.toString();
      final message =
          details['message']?.toString() ?? error.message ?? 'Network error';
      final retryAfter = _retryAfterFor(error.response);

      if (_isHtmlResponse(error.response)) {
        return const ConfigurationFailure(
          'The mobile API route is not deployed correctly.',
          code: 'deployment_misconfiguration',
          retryable: false,
        );
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          status == 408 ||
          status == 504) {
        return NetworkFailure(
          message,
          code: 'backend_timeout',
          retryAfter: retryAfter,
        );
      }
      if (error.type == DioExceptionType.connectionError ||
          error.response == null) {
        return NetworkFailure(
          message,
          code: code ?? 'network_error',
          retryAfter: retryAfter,
        );
      }
      if (status == 401 || status == 403) {
        return AuthFailure(
          message,
          code: code ?? status?.toString(),
          retryable: false,
        );
      }
      if (status == 429) {
        return NetworkFailure(
          message,
          code: code ?? 'rate_limited',
          retryAfter: retryAfter,
        );
      }
      if (status == 400 || status == 404 || status == 405 || status == 422) {
        return NetworkFailure(
          message,
          code: code ?? status?.toString(),
          retryable: false,
        );
      }
      if (code != null) {
        return NetworkFailure(
          message,
          code: code,
          retryAfter: retryAfter,
          retryable: _isRetryableStatus(status),
        );
      }
      return NetworkFailure(
        message,
        code: status?.toString(),
        retryAfter: retryAfter,
        retryable: _isRetryableStatus(status),
      );
    }

    if (error is AppFailure) return error;
    return const NetworkFailure('Something went wrong', code: 'unknown');
  }

  static bool _isRetryableStatus(int? status) {
    return status == null ||
        status == 408 ||
        status == 429 ||
        status == 500 ||
        status == 502 ||
        status == 503 ||
        status == 504;
  }

  static bool _isHtmlResponse(Response<dynamic>? response) {
    final contentType = response?.headers.value(Headers.contentTypeHeader);
    final data = response?.data;
    return contentType?.toLowerCase().contains('text/html') == true ||
        (data is String && data.trimLeft().startsWith('<!DOCTYPE html'));
  }

  static Duration? _retryAfterFor(Response<dynamic>? response) {
    final raw = response?.headers.value('retry-after');
    if (raw == null || raw.trim().isEmpty) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds != null && seconds >= 0) {
      return Duration(seconds: seconds);
    }
    final date = DateTime.tryParse(raw.trim());
    if (date == null) return null;
    final wait = date.difference(DateTime.now());
    return wait.isNegative ? Duration.zero : wait;
  }
}
