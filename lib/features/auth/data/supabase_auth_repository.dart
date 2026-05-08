import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/telemetry.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_state.dart';
import 'google_auth_failure_mapper.dart';

class SupabaseAuthRepository implements AuthRepository {
  static Future<void>? _googleInitializeFuture;
  static const _googleFailureMapper = GoogleAuthFailureMapper();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<AuthState> hydrate() async {
    if (!AppConfig.isSupabaseConfigured) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        return const AuthState(status: AuthStatus.unauthenticated);
      }
      final profile = await _ensureProfile();
      telemetry.event(TelemetryEvent.authSessionHydrated);
      return AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(id: session.user.id, email: session.user.email),
        profile: profile,
      );
    } catch (error) {
      telemetry.warn(TelemetryEvent.authError, {'code': 'hydrate_failed'});
      return AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: error.toString(),
      );
    }
  }

  @override
  Future<AuthState> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _assertConfigured();
    return _mapSupabaseErrors(operation: 'email_sign_in', () async {
      final response = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final profile = await _ensureProfile();
      return AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(id: response.user!.id, email: response.user!.email),
        profile: profile,
      );
    });
  }

  @override
  Future<AuthState> signUpWithEmailPassword({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _assertConfigured();
    return _mapSupabaseErrors(operation: 'email_sign_up', () async {
      final response = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'full_name': fullName.trim()},
        emailRedirectTo: '${AppConfig.authRedirectScheme}://auth/callback',
      );
      final profile = response.session == null
          ? null
          : await _ensureProfile(fullName: fullName.trim());
      return AuthState(
        status: response.session == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        user: response.user == null
            ? null
            : AppUser(id: response.user!.id, email: response.user!.email),
        profile: profile,
      );
    });
  }

  @override
  Future<AuthState> signInWithGoogle() async {
    _assertConfigured();
    _assertGoogleConfigured();
    return _mapSupabaseErrors(operation: 'google_sign_in', () async {
      await _ensureGoogleInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const AuthFailure(
          'Google sign-in is not supported on this platform build.',
          code: 'google_sign_in_unsupported',
        );
      }

      appLogger.info('google_sign_in_started', {
        'webClientConfigured': AppConfig.googleWebClientId.isNotEmpty,
        'iosClientConfigured': AppConfig.googleIosClientId.isNotEmpty,
      });

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(
          'Google did not return an ID token. Check Google client configuration.',
          code: 'google_id_token_missing',
        );
      }

      final response = await _client.auth.signInWithIdToken(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
      );
      final session = response.session;
      final user = response.user;

      if (session == null || user == null) {
        throw const AuthFailure(
          'Supabase could not create a Google session.',
          code: 'google_session_missing',
        );
      }

      final profile = await _ensureProfile(fullName: account.displayName);
      appLogger.info('google_sign_in_succeeded', {
        'hasEmail': user.email != null,
        'hasProfile': profile.id.isNotEmpty,
      });
      return AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(id: user.id, email: user.email),
        profile: profile,
      );
    });
  }

  @override
  Future<void> requestSignupOtp() async {
    _assertConfigured();
    await _mapSupabaseErrors(
      operation: 'request_signup_otp',
      () => _callFunction('request-signup-otp', {}),
    );
  }

  @override
  Future<void> verifySignupOtp({required String token}) async {
    _assertConfigured();
    await _mapSupabaseErrors(operation: 'verify_signup_otp', () async {
      await _callFunction('verify-signup-otp', {'token': token.trim()});
      await _client.auth.refreshSession();
    });
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _assertConfigured();
    await _mapSupabaseErrors(
      operation: 'password_reset',
      () => _client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: '${AppConfig.authRedirectScheme}://auth/reset',
      ),
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    _assertConfigured();
    await _mapSupabaseErrors(
      operation: 'password_update',
      () => _client.auth.updateUser(sb.UserAttributes(password: password)),
    );
  }

  @override
  Future<AuthState> refreshSessionOrLogout() async {
    _assertConfigured();
    try {
      final response = await _client.auth.refreshSession();
      if (response.session == null) {
        await _client.auth.signOut();
        return const AuthState(status: AuthStatus.expired);
      }
      final profile = await _ensureProfile();
      return AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(
          id: response.session!.user.id,
          email: response.session!.user.email,
        ),
        profile: profile,
      );
    } catch (_) {
      await _client.auth.signOut();
      return const AuthState(status: AuthStatus.expired);
    }
  }

  @override
  Future<void> signOut() async {
    if (!AppConfig.isSupabaseConfigured) return;
    await _client.auth.signOut();
    await _safeGoogleSignOut();
  }

  Future<void> _ensureGoogleInitialized() {
    final existing = _googleInitializeFuture;
    if (existing != null) return existing;

    final initialization = GoogleSignIn.instance.initialize(
      clientId: AppConfig.googleIosClientId.isEmpty
          ? null
          : AppConfig.googleIosClientId,
      serverClientId: AppConfig.googleWebClientId.isEmpty
          ? null
          : AppConfig.googleWebClientId,
    );
    _googleInitializeFuture = initialization;
    return initialization.catchError((Object error) {
      _googleInitializeFuture = null;
      throw error;
    });
  }

  Future<UserProfile> _ensureProfile({String? fullName}) async {
    final response = await _client.rpc(
      'ensure_user_profile',
      params: {'p_full_name': fullName},
    );
    if (response is Map) {
      return UserProfile.fromJson(Map<String, Object?>.from(response));
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Session expired.', code: 'session_expired');
    }
    return UserProfile(
      id: user.id,
      email: user.email,
      fullName: fullName ?? user.userMetadata?['full_name']?.toString(),
    );
  }

  Future<void> _callFunction(String name, Map<String, Object?> body) async {
    final response = await _client.functions.invoke(name, body: body);
    final data = response.data;
    if (response.status >= 400 || (data is Map && data['ok'] == false)) {
      throw AuthFailure(
        data is Map
            ? data['message']?.toString() ?? 'Auth function failed.'
            : 'Auth function failed.',
        code: data is Map ? data['code']?.toString() : name,
      );
    }
  }

  void _assertConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const ConfigurationFailure(
        'Supabase is not configured for this build. Run with npm run android so .env is injected.',
        code: 'supabase_not_configured',
      );
    }
  }

  void _assertGoogleConfigured() {
    final webClientId = AppConfig.googleWebClientId.trim();
    if (webClientId.isEmpty) {
      throw const ConfigurationFailure(
        'Google login is missing GOOGLE_WEB_CLIENT_ID for this build.',
        code: 'google_web_client_missing',
      );
    }
    if (!webClientId.endsWith('.apps.googleusercontent.com')) {
      throw const ConfigurationFailure(
        'Google login has an invalid GOOGLE_WEB_CLIENT_ID value.',
        code: 'google_web_client_invalid',
      );
    }
  }

  Future<void> _safeGoogleSignOut() async {
    if (AppConfig.googleWebClientId.isEmpty) return;
    try {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    } on GoogleSignInException catch (error) {
      appLogger.warn('google_sign_out_ignored', {
        'code': error.code.name,
        'hasDescription': error.description?.isNotEmpty ?? false,
      });
    } catch (error) {
      appLogger.warn('google_sign_out_ignored', {
        'errorType': error.runtimeType.toString(),
      });
    }
  }

  Future<T> _mapSupabaseErrors<T>(
    Future<T> Function() action, {
    required String operation,
  }) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on GoogleSignInException catch (error) {
      final failure = _googleFailureMapper.map(error);
      appLogger.warn('google_sign_in_error', {
        'operation': operation,
        'code': error.code.name,
        'failureCode': failure.code,
        'hasDescription': error.description?.isNotEmpty ?? false,
      });
      throw failure;
    } on sb.AuthException catch (error) {
      appLogger.warn('supabase_auth_error', {
        'operation': operation,
        'code': error.code,
        'statusCode': error.statusCode,
      });
      throw AuthFailure(
        _friendlyAuthMessage(error),
        code: error.code ?? error.statusCode ?? 'supabase_auth_error',
      );
    } on sb.PostgrestException catch (error) {
      appLogger.warn('supabase_postgrest_error', {
        'operation': operation,
        'code': error.code,
        'hasHint': error.hint != null,
      });
      throw AuthFailure(
        'Supabase profile setup failed. Please try again.',
        code: error.code ?? 'supabase_profile_error',
      );
    } on sb.FunctionException catch (error) {
      appLogger.warn('supabase_function_error', {
        'operation': operation,
        'status': error.status,
      });
      throw AuthFailure(
        'Supabase auth function failed. Please try again.',
        code: 'supabase_function_${error.status}',
      );
    }
  }

  String _friendlyAuthMessage(sb.AuthException error) {
    final code = error.code ?? '';
    if (code == 'invalid_credentials') {
      return 'Email or password is incorrect.';
    }
    if (code == 'email_not_confirmed') {
      return 'Please verify your email before logging in.';
    }
    if (code == 'user_already_exists') {
      return 'This email is already registered. Log in or reset your password.';
    }
    if (code == 'provider_disabled') {
      return 'Google login is not enabled in Supabase yet.';
    }
    if (error is sb.AuthRetryableFetchException) {
      return 'Could not reach Supabase. Check your connection and try again.';
    }
    return error.message;
  }
}
