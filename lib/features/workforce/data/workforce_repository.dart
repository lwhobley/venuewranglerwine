import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/workforce_models.dart';
import 'workforce_database.dart';
import 'workforce_connection.dart';

final workforceDatabaseProvider = Provider<WorkforceDatabase>((ref) {
  final db = WorkforceDatabase(workforceConnection());
  ref.onDispose(db.close);
  return db;
});
final workforceRepositoryProvider = Provider<WorkforceRepository>(
  (ref) => WorkforceRepository(
    Supabase.instance.client,
    ref.watch(workforceDatabaseProvider),
  ),
);

class WorkforceRepository {
  WorkforceRepository(this.client, this.database);
  final SupabaseClient client;
  final WorkforceDatabase database;
  String scope(String org, String venue) =>
      '${client.auth.currentUser!.id}/$org/$venue';
  Future<WorkforceSnapshot> load(
    String org,
    String venue,
    DateTime start,
    DateTime end,
  ) async {
    final requestScope = scope(org, venue);
    try {
      final data = Map<String, dynamic>.from(
        await client.rpc(
          'workforce_snapshot',
          params: {
            'p_org': org,
            'p_venue': venue,
            'p_start': start.toUtc().toIso8601String(),
            'p_end': end.toUtc().toIso8601String(),
          },
        ) as Map,
      );
      if (requestScope != scope(org, venue)) {
        throw const ValidationFailure(
          'Your session changed. Open the workspace again.',
        );
      }
      // Wage snapshots and delivery tokens are never persisted offline.
      final cache = {...data}
        ..remove('employee_wage_rates')
        ..remove('labor_targets')
        ..remove('labor_forecasts');
      cache['shift_change_events'] = (data['shift_change_events'] as List)
          .where(
            (event) => !{
              'employee_wage_rates',
              'labor_targets',
              'labor_forecasts',
            }.contains((event as Map)['entity_type']),
          )
          .toList();
      await database
          .into(database.workforceCache)
          .insertOnConflictUpdate(
            WorkforceCacheCompanion.insert(
              scope: requestScope,
              snapshot: jsonEncode(cache),
              capturedAt: DateTime.now().toUtc(),
            ),
          );
      return WorkforceSnapshot(data);
    } on PostgrestException catch (error) {
      throw mapWorkforceFailure(error);
    }
  }

  Future<WorkforceSnapshot?> cached(String org, String venue) async {
    final row = await (database.select(
      database.workforceCache,
    )..where((x) => x.scope.equals(scope(org, venue)))).getSingleOrNull();
    return row == null
        ? null
        : WorkforceSnapshot(jsonDecode(row.snapshot) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> send(
    String org,
    String venue,
    WorkCommand command,
  ) async {
    if (command.scope != scope(org, venue)) {
      throw const ValidationFailure('This draft belongs to another workspace.');
    }
    try {
      return Map<String, dynamic>.from(
        await client.rpc(
          'workforce_command',
          params: {
            'p_org': org,
            'p_venue': venue,
            'p_command': command.id,
            'p_action': command.action,
            'p_payload': command.payload,
          },
        ) as Map,
      );
    } on PostgrestException catch (error) {
      throw mapWorkforceFailure(error);
    }
  }

  WorkCommand command(
    String org,
    String venue,
    String action,
    Map<String, dynamic> payload,
  ) => WorkCommand(
    id: const Uuid().v4(),
    scope: scope(org, venue),
    action: action,
    payload: payload,
    createdAt: DateTime.now().toUtc(),
  );
  Future<void> keep(WorkCommand command) => database
      .into(database.workforcePending)
      .insertOnConflictUpdate(
        WorkforcePendingCompanion.insert(
          id: command.id,
          scope: command.scope,
          command: jsonEncode(command.toJson()),
          status: command.status,
          createdAt: command.createdAt,
        ),
      );
  Future<List<WorkCommand>> pending(String org, String venue) async =>
      (await (database.select(database.workforcePending)
                ..where((x) => x.scope.equals(scope(org, venue)))
                ..orderBy([(x) => OrderingTerm.asc(x.createdAt)]))
              .get())
          .map(
            (r) => WorkCommand.fromJson(
              jsonDecode(r.command) as Map<String, dynamic>,
            ),
          )
          .toList();
}

AppFailure mapWorkforceFailure(PostgrestException error) {
  const messages = {
    'clock_geofence_not_configured': 'Ask a manager to set this venue’s address and clock boundary in Scheduling rules.',
    'clock_location_required': 'Location is required to clock in or out.',
    'clock_location_invalid': 'Your location could not be verified. Try again with precise location enabled.',
    'clock_location_stale':
        'Your location expired. Try the clock action again.',
    'clock_location_inaccurate': 'Your location is not precise enough. Move closer to the venue and try again.',
    'clock_mock_location':
        'A simulated location cannot be used for a clock punch.',
    'clock_outside_geofence': 'You must be inside the venue’s clock boundary to clock in or out. Report a missed punch if you need manager help.',
    'stale_revision':
        'This record changed. Refresh and review your saved draft.',
    'request_changed': 'This request changed. Refresh before reviewing it.',
    'required_certification_missing': 'A required certification is missing or expires before this shift ends.',
    'required_skill_missing': 'A required skill has not been approved.',
    'staff_role_not_qualified':
        'This employee is not qualified for the job role.',
    'assignment_overlap': 'This employee already has an overlapping shift.',
    'availability_rest_or_hours_conflict': 'Availability, rest, or weekly hours conflict. An authorized manager can document an override.',
    'approved_time_off_conflict':
        'This shift conflicts with approved time off.',
    'workforce_permission_denied': 'You do not have permission for this action in this venue or department.',
    'assigned_shift_required':
        'Clock-in requires an assigned, published shift.',
    'shift_changed_or_started':
        'This shift changed or started. Refresh and submit a new request.',
    'recipient_acceptance_required':
        'The other employee must accept this swap first.',
    'release_conflicting_assignments_first':
        'Release conflicting assignments before approving time off.',
    'dst_gap_or_ambiguity_choose_explicit_time': 'The copied time falls in a daylight-saving gap or repeated hour. Create it with an explicit time.',
  };
  return ValidationFailure(
    messages[error.message] ?? error.message.replaceAll('_', ' '),
  );
}
