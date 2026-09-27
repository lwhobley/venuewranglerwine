import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class VenueClock {
  const VenueClock();

  DateTime toVenue(DateTime utc, String timeZone) {
    final location = tz.getLocation(timeZone);
    return tz.TZDateTime.from(utc.toUtc(), location);
  }

  String format(DateTime utc, String timeZone) {
    final local = toVenue(utc, timeZone);
    return DateFormat.yMMMd().add_jm().format(local);
  }

  bool isKnownZone(String timeZone) {
    try {
      tz.getLocation(timeZone);
      return true;
    } on tz.LocationNotFoundException {
      return false;
    }
  }
}

const hospitalityTimeZones = <String>[
  'UTC',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Phoenix',
  'America/Los_Angeles',
  'America/Anchorage',
  'Pacific/Honolulu',
  'Europe/London',
  'Europe/Paris',
];
