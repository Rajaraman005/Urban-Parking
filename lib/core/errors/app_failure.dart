sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.code, this.retryable = false});

  final String message;
  final String? code;
  final bool retryable;

  @override
  String toString() => 'AppFailure($code, $message)';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.code, super.retryable = true});
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.code, super.retryable});
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.code, super.retryable});
}

class ConfigurationFailure extends AppFailure {
  const ConfigurationFailure(super.message, {super.code, super.retryable});
}
