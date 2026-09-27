sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message);
}
