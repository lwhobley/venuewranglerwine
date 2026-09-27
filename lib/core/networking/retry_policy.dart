class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 200),
  });

  final int maxAttempts;
  final Duration baseDelay;

  Duration delayForAttempt(int attempt) {
    final shift = attempt <= 1 ? 0 : attempt - 1;
    return baseDelay * (1 << shift);
  }

  bool shouldRetry({
    required int attempt,
    required String method,
    required int? statusCode,
    required bool transportError,
    bool idempotent = false,
  }) {
    if (attempt >= maxAttempts) return false;
    final safeMethod = method.toUpperCase() == 'GET' ||
        method.toUpperCase() == 'HEAD' ||
        idempotent;
    if (!safeMethod) return false;
    if (transportError) return true;
    if (statusCode == null) return false;
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }
}
