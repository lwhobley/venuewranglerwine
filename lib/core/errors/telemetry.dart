import 'app_failure.dart';

abstract interface class Telemetry {
  void capture(AppFailure failure, {String? context});
}

class NoopTelemetry implements Telemetry {
  const NoopTelemetry();

  @override
  void capture(AppFailure failure, {String? context}) {}
}
