import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:venue_wrangler/features/workforce/domain/workforce_time.dart';
import 'package:venue_wrangler/features/workforce/domain/workforce_models.dart';
import 'package:venue_wrangler/features/workforce/data/workforce_database.dart';
import 'package:venue_wrangler/features/workforce/presentation/schedule_board.dart';
import 'package:venue_wrangler/features/workforce/presentation/workforce_forms.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);
  test('DST gaps cannot normalize into a different shift', () {
    expect(
      wallTimeCandidates(DateTime.utc(2027, 3, 14, 2, 30), 'America/Chicago'),
      isEmpty,
    );
  });
  test('DST fold exposes both exact instants', () {
    final times = wallTimeCandidates(
      DateTime.utc(2027, 11, 7, 1, 30),
      'America/Chicago',
    );
    expect(times, [
      DateTime.utc(2027, 11, 7, 6, 30),
      DateTime.utc(2027, 11, 7, 7, 30),
    ]);
  });
  test('ordinary venue wall time ignores the device time zone', () {
    expect(wallTimeCandidates(DateTime.utc(2027, 1, 5, 9), 'America/Chicago'), [
      DateTime.utc(2027, 1, 5, 15),
    ]);
  });
  test('half-hour DST transitions are explicit', () {
    expect(
      wallTimeCandidates(
        DateTime.utc(2027, 4, 4, 1, 45),
        'Australia/Lord_Howe',
      ),
      hasLength(2),
    );
  });
  test('touching intervals do not overlap; overnight intervals do', () {
    expect(
      intervalsOverlap(
        DateTime.utc(2027, 1, 1, 23),
        DateTime.utc(2027, 1, 2, 3),
        DateTime.utc(2027, 1, 2, 3),
        DateTime.utc(2027, 1, 2, 8),
      ),
      isFalse,
    );
    expect(
      intervalsOverlap(
        DateTime.utc(2027, 1, 1, 23),
        DateTime.utc(2027, 1, 2, 3),
        DateTime.utc(2027, 1, 2, 2),
        DateTime.utc(2027, 1, 2, 8),
      ),
      isTrue,
    );
  });
  test('decimal labor arithmetic retains fractional rates and overtime', () {
    expect(laborCost('12.3456', 360), '74.07');
    expect(laborCost('20.0000', 180, overtimeMinutes: 60), '70.00');
    expect(laborCost('0.1000', 6), '0.01');
    expect(() => laborCost('12.12345', 60), throwsFormatException);
  });
  test('models preserve expected revision and UTC through serialization', () {
    final command = WorkCommand(
      id: 'cmd',
      scope: 'u/o/v',
      action: 'save_shift',
      payload: {'revision': 7, 'starts_at': '2027-01-05T15:00:00Z'},
      createdAt: DateTime.utc(2027, 1, 1),
    );
    final replay = WorkCommand.fromJson(command.toJson());
    expect(replay, command);
    expect(() => replay.payload['revision'] = 8, throwsUnsupportedError);
  });
  test('offline storage isolates user and venue, retains review states, clears on logout', () async {
    final db = WorkforceDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.workforcePending)
        .insert(
          WorkforcePendingCompanion.insert(
            id: 'one',
            scope: 'alice/org/first',
            command: '{}',
            status: 'needs_review',
            createdAt: DateTime.utc(2027),
          ),
        );
    await db
        .into(db.workforcePending)
        .insert(
          WorkforcePendingCompanion.insert(
            id: 'two',
            scope: 'bob/org/first',
            command: '{}',
            status: 'pending',
            createdAt: DateTime.utc(2027),
          ),
        );
    final rows = await (db.select(
      db.workforcePending,
    )..where((r) => r.scope.equals('alice/org/first'))).get();
    expect(rows.single.id, 'one');
    expect(rows.single.status, 'needs_review');
    await db.clear();
    expect(await db.select(db.workforcePending).get(), isEmpty);
  });
  testWidgets(
    'overnight shifts show both day segments with actionable details',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final shift = WorkShift(
        id: 'shift',
        organizationId: 'o',
        venueId: 'v',
        roleKey: 'server',
        startsAt: DateTime.utc(2027, 1, 6, 5),
        endsAt: DateTime.utc(2027, 1, 6, 9),
        status: 'published',
      );
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleBoard(
                shifts: [shift],
                staff: const [],
                assignments: const [],
                start: DateTime.utc(2027, 1, 5),
                days: 2,
                zone: 'America/Chicago',
                roleFirst: true,
                canEdit: true,
                onEdit: (_) => selected = true,
                onMove: (_, _) {},
                onAssign: (_, _) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Continues overnight'), findsOneWidget);
      expect(find.text('Continued from prior day'), findsOneWidget);
      await tester.tap(find.text('Edit / assign').first);
      expect(selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('mobile schedule scrolls horizontally without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScheduleBoard(
              shifts: const [],
              staff: const [],
              assignments: const [],
              start: DateTime.utc(2027, 1, 5),
              days: 7,
              zone: 'America/Chicago',
              roleFirst: false,
              canEdit: false,
              onEdit: (_) {},
              onMove: (_, _) {},
              onAssign: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Unassigned'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging a shift to another day invokes a concrete move', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final shift = WorkShift(
      id: 's',
      organizationId: 'o',
      venueId: 'v',
      roleKey: 'server',
      startsAt: DateTime.utc(2027, 1, 5, 16),
      endsAt: DateTime.utc(2027, 1, 5, 22),
      status: 'draft',
    );
    DateTime? moved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScheduleBoard(
              shifts: [shift],
              staff: const [],
              assignments: const [],
              start: DateTime.utc(2027, 1, 5),
              days: 2,
              zone: 'America/Chicago',
              roleFirst: true,
              canEdit: true,
              onEdit: (_) {},
              onMove: (_, day) => moved = day,
              onAssign: (_, _) {},
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Edit / assign')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(220, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moved, DateTime.utc(2027, 1, 6));
  });
  testWidgets('shift form rejects missing job and invalid dates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => workForm(
                context,
                title: 'New shift',
                fields: const [
                  WorkField('job_role_id', 'Job role', reference: 'job_roles'),
                  WorkField('starts_at', 'Starts at', kind: 'timestamp'),
                ],
                snapshot: WorkforceSnapshot({'job_roles': []}),
                zone: 'America/Chicago',
              ),
              child: const Text('Create'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Choose job role'), findsOneWidget);
    expect(find.text('Enter starts at'), findsOneWidget);
  });
}
