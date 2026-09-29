import 'package:timezone/timezone.dart' as tz;

/// All matches for a wall time. No match is a DST gap; two matches require a choice.
List<DateTime> wallTimeCandidates(DateTime wall, String zone) {
  if (!wall.isUtc) {
    throw const FormatException(
      'Wall-time components must use UTC to avoid device-timezone normalization.',
    );
  }
  final location = tz.getLocation(zone);
  final nominal = DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  );
  final offsets = <int>{};
  for (var h = -36; h <= 36; h++) {
    offsets.add(
      tz.TZDateTime.from(
        nominal.add(Duration(hours: h)),
        location,
      ).timeZoneOffset.inMilliseconds,
    );
  }
  final matches = <DateTime>[];
  for (final offset in offsets) {
    final utc = nominal.subtract(Duration(milliseconds: offset));
    final local = tz.TZDateTime.from(utc, location);
    if (local.year == wall.year &&
        local.month == wall.month &&
        local.day == wall.day &&
        local.hour == wall.hour &&
        local.minute == wall.minute) {
      matches.add(utc);
    }
  }
  return matches..sort();
}

bool intervalsOverlap(DateTime a, DateTime b, DateTime c, DateTime d) =>
    a.isBefore(d) && c.isBefore(b);

/// Wage rate has four decimal places; calculate in integers and round half up to cents.
String laborCost(
  String rate,
  int paidMinutes, {
  int overtimeMinutes = 0,
  String multiplier = '1.5000',
}) {
  BigInt units(String value) {
    if (!RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(value)) {
      throw const FormatException('Invalid wage');
    }
    final parts = value.split('.');
    return BigInt.parse(parts[0]) * BigInt.from(10000) +
        BigInt.parse((parts.length > 1 ? parts[1] : '').padRight(4, '0'));
  }

  if (paidMinutes < 0 || overtimeMinutes < 0 || overtimeMinutes > paidMinutes) {
    throw const FormatException('Invalid minutes');
  }
  final weighted =
      BigInt.from(paidMinutes - overtimeMinutes) * BigInt.from(10000) +
      BigInt.from(overtimeMinutes) * units(multiplier);
  final cents =
      (units(rate) * weighted + BigInt.from(30000000)) ~/ BigInt.from(60000000);
  return '${cents ~/ BigInt.from(100)}.${(cents % BigInt.from(100)).toString().padLeft(2, '0')}';
}
