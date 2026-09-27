sealed class AuthState {
  const AuthState();
}

class AuthUnconfigured extends AuthState {
  const AuthUnconfigured();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn({
    required this.userId,
    required this.email,
    required this.emailVerified,
    required this.passwordRecovery,
  });

  final String userId;
  final String email;
  final bool emailVerified;
  final bool passwordRecovery;
}

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.emailVerified,
    required this.passwordRecovery,
  });

  final String userId;
  final String email;
  final bool emailVerified;
  final bool passwordRecovery;
}
