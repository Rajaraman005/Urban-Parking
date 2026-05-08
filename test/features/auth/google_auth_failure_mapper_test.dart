import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:urban_parking/features/auth/data/google_auth_failure_mapper.dart';

void main() {
  const mapper = GoogleAuthFailureMapper();

  test('maps Google configuration failures to actionable auth copy', () {
    final failure = mapper.map(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'OAuth client is misconfigured.',
      ),
    );

    expect(failure.code, 'google_configuration_error');
    expect(failure.retryable, isFalse);
    expect(failure.message, contains('SHA-1'));
    expect(failure.message, contains('web client ID'));
  });

  test('maps Credential Manager failures to Android SHA guidance', () {
    final failure = mapper.map(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'GetCredentialResponse error returned from framework',
      ),
    );

    expect(failure.code, 'google_sign_in_unknown');
    expect(failure.retryable, isTrue);
    expect(failure.message, contains('Credential Manager'));
    expect(failure.message, contains('SHA-1'));
  });

  test('keeps user cancellation retryable', () {
    final failure = mapper.map(
      const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    );

    expect(failure.code, 'google_sign_in_canceled');
    expect(failure.retryable, isTrue);
  });
}
