import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/app_failure.dart';

class GoogleAuthFailureMapper {
  const GoogleAuthFailureMapper();

  AuthFailure map(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => const AuthFailure(
        'Google sign-in was cancelled. If this happened after choosing an account, verify this Android build SHA-1 is registered for Google login.',
        code: 'google_sign_in_canceled',
        retryable: true,
      ),
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError => const AuthFailure(
        'Google login is not configured correctly for this build. Verify the package name, SHA-1 certificate, and web client ID.',
        code: 'google_configuration_error',
      ),
      GoogleSignInExceptionCode.interrupted => const AuthFailure(
        'Google sign-in was interrupted. Please keep the app open and try again.',
        code: 'google_sign_in_interrupted',
        retryable: true,
      ),
      GoogleSignInExceptionCode.uiUnavailable => const AuthFailure(
        'Google sign-in UI is not available on this device right now. Update Google Play services and try again.',
        code: 'google_sign_in_ui_unavailable',
        retryable: true,
      ),
      GoogleSignInExceptionCode.userMismatch => const AuthFailure(
        'Google returned a different account than the active sign-in session. Sign out and try again.',
        code: 'google_user_mismatch',
        retryable: true,
      ),
      GoogleSignInExceptionCode.unknownError => AuthFailure(
        _unknownMessage(error),
        code: 'google_sign_in_unknown',
        retryable: true,
      ),
    };
  }

  static String _unknownMessage(GoogleSignInException error) {
    final description = error.description?.toLowerCase() ?? '';
    final details = error.details?.toString().toLowerCase() ?? '';
    final combined = '$description $details';
    if (combined.contains('credential')) {
      return 'Google Credential Manager could not create a sign-in credential. Verify this Android build SHA-1 is registered for Google login.';
    }
    return 'Google sign-in failed before Supabase received a token. Please try again.';
  }
}
