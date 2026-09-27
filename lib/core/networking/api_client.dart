import 'package:dio/dio.dart';

import 'retry_policy.dart';

Dio createApiClient({
  required String baseUrl,
  RetryPolicy policy = const RetryPolicy(),
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.interceptors.add(_RetryInterceptor(policy));
  return dio;
}

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._policy);

  final RetryPolicy _policy;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = err.requestOptions.extra['attempt'] as int? ?? 1;
    final retry = _policy.shouldRetry(
      attempt: attempt,
      method: err.requestOptions.method,
      statusCode: err.response?.statusCode,
      transportError: err.type == DioExceptionType.connectionError ||
          err.type == DioExceptionType.connectionTimeout,
      idempotent: err.requestOptions.extra['idempotent'] == true,
    );
    if (!retry) {
      handler.next(err);
      return;
    }
    await Future<void>.delayed(_policy.delayForAttempt(attempt));
    err.requestOptions.extra['attempt'] = attempt + 1;
    try {
      final response = await Dio().fetch<dynamic>(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (next) {
      handler.next(next);
    }
  }
}
