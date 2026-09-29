import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef FloorRow = Map<String, dynamic>;

const floorStatuses = {
  'available': 'Clean & ready',
  'reserved': 'Held',
  'seated': 'Seated',
  'dirty': 'Dirty',
  'cleaning': 'Cleaning',
  'blocked': 'Out of service',
};
Color floorStatusColor(String status) => switch (status) {
  'available' => const Color(0xff2c7567),
  'reserved' => const Color(0xff997016),
  'seated' => const Color(0xff3d65a7),
  'dirty' => const Color(0xffa6473b),
  'cleaning' => const Color(0xff8061a3),
  _ => const Color(0xff647078),
};

double floorNumber(FloorRow row, String key, [double fallback = 0]) =>
    (row[key] as num?)?.toDouble() ?? fallback;

class FloorSnapshot {
  FloorSnapshot(FloorRow data)
    : plans = _rows(data['plans']),
      tables = _rows(data['tables']),
      objects = _rows(data['objects']),
      groups = _rows(data['groups']),
      parties = _rows(data['parties']),
      guests = _rows(data['guests']),
      servers = _rows(data['servers']),
      permissions = Map<String, dynamic>.unmodifiable(
        data['permissions'] as Map? ?? {},
      );
  final List<FloorRow> plans, tables, objects, groups, parties, guests, servers;
  final FloorRow permissions;
  bool can(String action) => permissions[action] == true;
  static List<FloorRow> _rows(dynamic rows) => List.unmodifiable(
    (rows as List? ?? []).map(
      (r) => Map<String, dynamic>.unmodifiable(r as Map),
    ),
  );
  List<FloorRow> seatingUnit(String tableId) {
    final table = tables.where((t) => t['id'] == tableId).firstOrNull;
    if (table == null) return [];
    return tables
        .where(
          (t) =>
              t['id'] == tableId ||
              (table['group_id'] != null && t['group_id'] == table['group_id']),
        )
        .toList();
  }
}

/// Keeps furniture in plan coordinates regardless of device zoom or pixel density.
Offset clampFloorPosition(
  Offset position,
  Size item,
  Size plan, {
  bool snap = true,
}) {
  final x = snap ? (position.dx / 10).round() * 10.0 : position.dx;
  final y = snap ? (position.dy / 10).round() * 10.0 : position.dy;
  return Offset(
    x.clamp(0, math.max(0, plan.width - item.width)),
    y.clamp(0, math.max(0, plan.height - item.height)),
  );
}

List<FloorRow> eligibleSeatingUnits(
  FloorSnapshot snapshot,
  FloorRow party, {
  bool forAssignment = false,
  DateTime? now,
}) {
  final seen = <String>{};
  final rows = <FloorRow>[];
  final instant = now ?? DateTime.now().toUtc();
  final start = forAssignment
      ? DateTime.parse(party['reserved_at'] as String)
      : instant;
  final end = start.add(
    Duration(minutes: party['duration_minutes'] as int? ?? 90),
  );
  for (final table in snapshot.tables) {
    final key = (table['group_id'] ?? table['id']) as String;
    if (!seen.add(key) || table['plan_id'] == null) continue;
    final unit = snapshot.seatingUnit(table['id'] as String);
    final ids = unit.map((t) => t['id']).toSet();
    final own = (party['table_ids'] as List? ?? []).toSet();
    if (unit.any(
      (t) =>
          !['available', 'reserved'].contains(t['status']) &&
          !(party['status'] == 'seated' && own.contains(t['id'])),
    )) {
      continue;
    }
    if (unit.fold<int>(0, (n, t) => n + (t['capacity'] as int)) <
        (party['party_size'] as int)) {
      continue;
    }
    if (party['accessibility_requested'] == true &&
        !unit.any((t) => t['accessible'] == true)) {
      continue;
    }
    final clash = snapshot.parties.any((other) {
      if (other['id'] == party['id'] ||
          !(other['table_ids'] as List? ?? []).any(ids.contains)) {
        return false;
      }
      if (other['status'] == 'seated') return true;
      if (!['booked', 'waiting'].contains(other['status'])) return false;
      final otherStart = DateTime.parse(other['reserved_at'] as String);
      final otherEnd = otherStart.add(
        Duration(minutes: other['duration_minutes'] as int? ?? 90),
      );
      return start.isBefore(otherEnd) && otherStart.isBefore(end);
    });
    if (!clash) rows.add(table);
  }
  return rows;
}
