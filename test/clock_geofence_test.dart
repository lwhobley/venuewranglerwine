import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:venue_wrangler/core/errors/app_failure.dart';
import 'package:venue_wrangler/features/workforce/data/clock_location.dart';
import 'package:venue_wrangler/features/workforce/domain/workforce_models.dart';
import 'package:venue_wrangler/features/workforce/presentation/workforce_forms.dart';

class TestLocation extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requested = LocationPermission.whileInUse;
  int fixes = 0, requests = 0;
  LocationSettings? settings;
  bool fail = false;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    fixes++;
    settings = locationSettings;
    if (fail) throw StateError('sensor unavailable');
    return Position(
      latitude: 41.88,
      longitude: -87.63,
      timestamp: DateTime.utc(2026, 9, 29),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late GeolocatorPlatform original;
  late TestLocation location;
  setUp(() {
    original = GeolocatorPlatform.instance;
    location = TestLocation();
    GeolocatorPlatform.instance = location;
  });
  tearDown(() => GeolocatorPlatform.instance = original);
  setUpAll(tzdata.initializeTimeZones);
  test('disabled location cannot produce a punch fix', () async {
    location.enabled = false;
    await expectLater(
      captureClockLocation(),
      throwsA(isA<ValidationFailure>()),
    );
    expect(location.fixes, 0);
  });
  test('permanent denial does not prompt again or read GPS', () async {
    location.permission = LocationPermission.deniedForever;
    await expectLater(
      captureClockLocation(),
      throwsA(isA<ValidationFailure>()),
    );
    expect(location.requests, 0);
    expect(location.fixes, 0);
  });
  test('denied permission requests once and remains fail closed', () async {
    location.permission = LocationPermission.denied;
    location.requested = LocationPermission.denied;
    await expectLater(
      captureClockLocation(),
      throwsA(isA<ValidationFailure>()),
    );
    expect(location.requests, 1);
    expect(location.fixes, 0);
  });
  test('a granted punch gets one high accuracy fix with a timeout', () async {
    location.permission = LocationPermission.denied;
    final fix = await captureClockLocation();
    expect(location.fixes, 1);
    expect(location.requests, 1);
    expect(location.settings!.accuracy, LocationAccuracy.high);
    expect(location.settings!.timeLimit, const Duration(seconds: 25));
    expect(fix['longitude'], -87.63);
    expect(fix['accuracy_m'], 5);
    expect(fix['is_mocked'], false);
    expect(fix['captured_at'], '2026-09-29T00:00:00.000Z');
  });
  test(
    'sensor failure offers a reviewed claim rather than a fake fix',
    () async {
      location.fail = true;
      await expectLater(
        captureClockLocation(),
        throwsA(isA<ValidationFailure>()),
      );
    },
  );
  testWidgets('geofence radius and coordinates reject invalid settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => workForm(
                context,
                title: 'Boundary',
                fields: const [
                  WorkField(
                    'geofence_latitude',
                    'Latitude',
                    kind: 'coordinate',
                  ),
                  WorkField('geofence_radius_ft', 'Radius', kind: 'int'),
                ],
                snapshot: WorkforceSnapshot({}),
                zone: 'America/Chicago',
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '-91');
    await tester.enterText(find.byType(TextFormField).at(1), '1001');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid coordinate'), findsOneWidget);
    expect(find.text('Choose 1–1,000 feet'), findsOneWidget);
  });
}
