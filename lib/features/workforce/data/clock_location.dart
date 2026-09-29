import 'package:geolocator/geolocator.dart';

import '../../../core/errors/app_failure.dart';

/// One foreground fix per punch. No background location stream is started.
Future<Map<String, dynamic>> captureClockLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ValidationFailure(
        'Turn on location services to clock in or out.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ValidationFailure(
        'Allow location access to clock in or out. You can report a missed punch for manager review.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 25),
      ),
    );
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy_m': position.accuracy,
      'captured_at': position.timestamp.toUtc().toIso8601String(),
      'is_mocked': position.isMocked,
    };
  } on AppFailure {
    rethrow;
  } catch (_) {
    throw const ValidationFailure(
      'Could not get a precise location. Try again near the venue, or report a missed punch for manager review.',
    );
  }
}
