import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/core/errors/app_failure.dart';
import 'package:urban_parking/core/network/api_client.dart';

void main() {
  test('classifies HTML 404 responses as deployment misconfiguration', () {
    final failure = ApiClient.toFailure(
      DioException(
        requestOptions: RequestOptions(path: '/geo-discovery/search'),
        response: Response<String>(
          data: '<!DOCTYPE html><html><body>404</body></html>',
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['text/html; charset=utf-8'],
          }),
          requestOptions: RequestOptions(path: '/geo-discovery/search'),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(failure, isA<ConfigurationFailure>());
    expect(failure.code, 'deployment_misconfiguration');
    expect(failure.retryable, isFalse);
  });

  test('honors retry-after on 429 responses', () {
    final failure = ApiClient.toFailure(
      DioException(
        requestOptions: RequestOptions(path: '/geo-discovery/search'),
        response: Response<Map<String, Object?>>(
          data: const {'code': 'rate_limited', 'message': 'Too many requests'},
          headers: Headers.fromMap({
            'retry-after': ['7'],
          }),
          requestOptions: RequestOptions(path: '/geo-discovery/search'),
          statusCode: 429,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(failure, isA<NetworkFailure>());
    expect((failure as NetworkFailure).retryAfter, const Duration(seconds: 7));
    expect(failure.retryable, isTrue);
  });
}
