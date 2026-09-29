import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:venue_wrangler/features/floor_plan/domain/floor_models.dart';
import 'package:venue_wrangler/features/floor_plan/data/floor_reference.dart';
import 'package:venue_wrangler/features/floor_plan/presentation/floor_canvas.dart';
import 'package:venue_wrangler/features/floor_plan/presentation/floor_forms.dart';

FloorRow table(
  String id, {
  String? group,
  String status = 'available',
  int seats = 4,
  bool accessible = false,
}) => {
  'id': id,
  'label': id,
  'plan_id': 'room',
  'group_id': group,
  'status': status,
  'capacity': seats,
  'accessible': accessible,
  'x': 200.0,
  'y': 200.0,
  'width': 120.0,
  'height': 90.0,
  'shape': 'rectangle',
  'angle': 0.0,
};
FloorRow party({
  String id = 'party',
  int guests = 6,
  bool accessible = false,
}) => {
  'id': id,
  'party_size': guests,
  'status': 'booked',
  'duration_minutes': 90,
  'reserved_at': '2027-01-01T18:00:00Z',
  'table_ids': <String>[],
  'accessibility_requested': accessible,
};
FloorSnapshot snapshot(
  List<FloorRow> tables, [
  List<FloorRow> parties = const [],
]) => FloorSnapshot({'tables': tables, 'parties': parties});

void main() {
  setUpAll(tzdata.initializeTimeZones);
  test('new rooms and snapshots contain no example furniture', () {
    final data = FloorSnapshot({});
    expect(data.plans, isEmpty);
    expect(data.tables, isEmpty);
    expect(data.objects, isEmpty);
  });
  test('drop coordinates clamp and snap in plan space', () {
    expect(
      clampFloorPosition(
        const Offset(-50, 1000),
        const Size(120, 90),
        const Size(1200, 800),
      ),
      const Offset(0, 710),
    );
    expect(
      clampFloorPosition(
        const Offset(236, 143),
        const Size(120, 90),
        const Size(1200, 800),
      ),
      const Offset(240, 140),
    );
    expect(
      clampFloorPosition(
        const Offset(236, 143),
        const Size(120, 90),
        const Size(1200, 800),
        snap: false,
      ),
      const Offset(236, 143),
    );
  });
  test('combinations count seats once and reject mixed dirty members', () {
    final data = snapshot([
      table('A', group: 'unit'),
      table('B', group: 'unit'),
      table('C', seats: 4),
    ]);
    expect(eligibleSeatingUnits(data, party()).map((r) => r['id']), ['A']);
    expect(data.seatingUnit('B').length, 2);
    expect(
      eligibleSeatingUnits(
        snapshot([
          table('A', group: 'unit'),
          table('B', group: 'unit', status: 'dirty'),
        ]),
        party(),
      ),
      isEmpty,
    );
  });
  test('accessible requests require an accessible member', () {
    expect(
      eligibleSeatingUnits(
        snapshot([table('A', seats: 8)]),
        party(accessible: true),
      ),
      isEmpty,
    );
    expect(
      eligibleSeatingUnits(
        snapshot([
          table('A', group: 'unit', accessible: true),
          table('B', group: 'unit'),
        ]),
        party(accessible: true),
      ),
      hasLength(1),
    );
  });
  test('booking windows exclude overlap but permit touching intervals', () {
    final other = {
      ...party(id: 'other', guests: 2),
      'table_ids': ['A'],
      'reserved_at': '2027-01-01T19:00:00Z',
    };
    expect(
      eligibleSeatingUnits(
        snapshot([table('A', seats: 8)], [other]),
        party(),
        forAssignment: true,
      ),
      isEmpty,
    );
    other['reserved_at'] = '2027-01-01T19:30:00Z';
    expect(
      eligibleSeatingUnits(
        snapshot([table('A', seats: 8)], [other]),
        party(),
        forAssignment: true,
      ),
      hasLength(1),
    );
  });
  test(
    'physical seated occupancy remains exclusive after its expected turn time',
    () {
      final other = {
        ...party(id: 'other', guests: 2),
        'table_ids': ['A'],
        'status': 'seated',
        'reserved_at': '2026-01-01T18:00:00Z',
      };
      expect(
        eligibleSeatingUnits(
          snapshot([table('A', seats: 8)], [other]),
          party(),
          forAssignment: true,
        ),
        isEmpty,
      );
    },
  );
  test('snapshot furniture cannot be mutated accidentally', () {
    final data = snapshot([table('A')]);
    expect(() => data.tables.first['capacity'] = 99, throwsUnsupportedError);
  });
  testWidgets(
    'canvas exposes table capacity and status without mobile overflow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 440,
              child: FloorCanvas(
                plan: {'id': 'room', 'width': 1200, 'height': 800},
                tables: [table('A')],
                objects: const [],
                selected: const {},
                editing: false,
                onSelect: (_) {},
                onMove: (_, _) {},
                onMoveStart: () {},
                onMoveEnd: (_) {},
                onDrop: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4 seats'), findsOneWidget);
      expect(find.text('Clean & ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('a real drag moves furniture in zoomed plan coordinates', (
    tester,
  ) async {
    var row = table('A');
    Offset? moved;
    var starts = 0, ends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: 400,
              child: StatefulBuilder(
                builder: (context, setState) => FloorCanvas(
                  plan: {'id': 'room', 'width': 1200, 'height': 800},
                  tables: [row],
                  objects: const [],
                  selected: const {},
                  editing: true,
                  onSelect: (_) {},
                  onMove: (id, pos) {
                    moved = pos;
                    setState(() => row = {...row, 'x': pos.dx, 'y': pos.dy});
                  },
                  onMoveStart: () => starts++,
                  onMoveEnd: (_) => ends++,
                  onDrop: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('floor-A')),
      const Offset(80, 35),
    );
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(ends, 1);
    expect(moved, isNotNull);
    expect(moved!.dx, greaterThan(250));
    expect(moved!.dy, greaterThan(200));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'vertical table drag moves both axes without scrolling the host page',
    (tester) async {
      var row = table('A');
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ListView(
                controller: scroll,
                children: [
                  const SizedBox(height: 60),
                  SizedBox(
                    height: 400,
                    child: FloorCanvas(
                      plan: {'id': 'room', 'width': 1200, 'height': 800},
                      tables: [row],
                      objects: const [],
                      selected: const {},
                      editing: true,
                      onSelect: (_) {},
                      onMove: (_, pos) => setState(
                        () => row = {...row, 'x': pos.dx, 'y': pos.dy},
                      ),
                      onMoveStart: () {},
                      onMoveEnd: (_) {},
                      onDrop: (_, _) {},
                    ),
                  ),
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('floor-A'))),
      );
      await gesture.moveBy(const Offset(2, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(30, 80));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(floorNumber(row, 'x'), greaterThan(240));
      expect(floorNumber(row, 'y'), greaterThan(300));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
    },
  );
  testWidgets('live table tap selects the intended table', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: FloorCanvas(
              plan: {'id': 'room', 'width': 1200, 'height': 800},
              tables: [table('A')],
              objects: const [],
              selected: const {},
              editing: false,
              onSelect: (id) => selected = id,
              onMove: (_, _) {},
              onMoveStart: () {},
              onMoveEnd: (_) {},
              onDrop: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('floor-A')));
    expect(selected, 'A');
  });
  testWidgets(
    'seat-capacity form rejects fractional numbers and blank labels',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => floorForm(
                context,
                'Table',
                const [
                  FloorField('label', 'Table label', required: true),
                  FloorField(
                    'capacity',
                    'Capacity',
                    kind: 'int',
                    required: true,
                    min: 1,
                    max: 20,
                  ),
                ],
                {'capacity': 4},
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '2.5');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Enter table label'), findsOneWidget);
      expect(find.textContaining('whole number'), findsOneWidget);
    },
  );
  testWidgets('venue wall-time form rejects a DST gap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => floorForm(
              context,
              'Reservation',
              const [
                FloorField(
                  'reserved_at',
                  'Reservation time',
                  kind: 'instant',
                  required: true,
                ),
              ],
              {},
              zone: 'America/Chicago',
            ),
            child: const Text('Book'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2027-03-14 02:30');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not exist'), findsOneWidget);
  });
  testWidgets('picture references are decoded and normalized to a PNG', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 80, 40),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(80, 40);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final result = await readFloorReference(
          'diagram.png',
          bytes!.buffer.asUint8List(),
          (_) => Future.value(null),
        );
        expect(result!.width, 80);
        expect(result.height, 40);
        expect(result.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      } finally {
        image.dispose();
        picture.dispose();
      }
    });
  });
  test('empty and oversized reference uploads fail before decoding', () async {
    await expectLater(
      readFloorReference('x.png', Uint8List(0), (_) => Future.value(null)),
      throwsFormatException,
    );
    await expectLater(
      readFloorReference(
        'x.png',
        Uint8List(20 * 1024 * 1024 + 1),
        (_) => Future.value(null),
      ),
      throwsFormatException,
    );
  });
}
