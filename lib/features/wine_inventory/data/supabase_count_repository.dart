import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../domain/count_repository.dart';

class SupabaseCountRepository implements CountRepository {
  SupabaseCountRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CountSessionSummary>> listSessions(String venueId) {
    return _guard(() async {
      final raw = await _client.rpc('list_count_sessions', params: {'p_venue_id': venueId});
      return _list(raw).map((row) {
        return CountSessionSummary(
          id: row['id'] as String,
          kind: row['kind'] as String,
          mode: row['mode'] as String,
          status: row['status'] as String,
          createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
          countedLines: _int(row['counted_lines']),
          openLines: _int(row['open_lines']),
        );
      }).toList();
    });
  }

  @override
  Future<String> startSession({
    required String organizationId,
    required String venueId,
    required String kind,
    required String mode,
    String? locationId,
  }) {
    return _guard(() async {
      final id = await _client.rpc(
        'start_count_session',
        params: {
          'p_organization_id': organizationId,
          'p_venue_id': venueId,
          'p_kind': kind,
          'p_mode': mode,
          'p_location_id': locationId,
        },
      );
      return id.toString();
    });
  }

  @override
  Future<CountEntryResult> recordEntry({
    required String sessionId,
    required String clientEntryId,
    required String locationCode,
    required String sku,
    required String quantity,
    required String reason,
  }) {
    return _guard(() async {
      final raw = await _client.rpc(
        'record_count_entry',
        params: {
          'p_session_id': sessionId,
          'p_client_entry_id': clientEntryId,
          'p_location_code': locationCode,
          'p_sku': sku,
          'p_quantity': quantity,
          'p_reason': reason,
        },
      );
      final map = Map<String, dynamic>.from(raw as Map);
      return CountEntryResult(
        status: map['status'] as String,
        lineId: map['line_id'].toString(),
      );
    });
  }

  @override
  Future<void> submit(String sessionId) {
    return _guard(() => _client.rpc('submit_count_session', params: {'p_session_id': sessionId}));
  }

  @override
  Future<int> approve(String sessionId) {
    return _guard(() async {
      final written = await _client.rpc('approve_count_session', params: {'p_session_id': sessionId});
      return written as int? ?? int.parse(written.toString());
    });
  }

  @override
  Future<void> reject(String sessionId) {
    return _guard(() => _client.rpc('reject_count_session', params: {'p_session_id': sessionId}));
  }

  @override
  Future<void> resolveConflict({required String lineId, required String quantity}) {
    return _guard(
      () => _client.rpc(
        'resolve_count_conflict',
        params: {'p_line_id': lineId, 'p_quantity': quantity},
      ),
    );
  }

  @override
  Future<List<CountSheetLine>> sheet(String sessionId) {
    return _guard(() async {
      final raw = await _client.rpc('count_sheet', params: {'p_session_id': sessionId});
      return _list(raw).map((row) {
        return CountSheetLine(
          lineId: row['line_id'] as String,
          locationCode: row['location_code'] as String,
          sku: row['sku'] as String? ?? '',
          label: row['label'] as String? ?? '',
          countedQuantity: _qty(row['counted_quantity']),
          expectedQuantity: _qty(row['expected_quantity']),
          conflict: row['conflict'] == true,
          otherCountedQuantity: _qty(row['other_counted_quantity']),
          reason: row['reason'] as String? ?? '',
          mode: row['mode'] as String? ?? 'blind',
          status: row['status'] as String? ?? 'in_progress',
        );
      }).toList();
    });
  }

  int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String? _qty(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    if (text.isEmpty) return null;
    final parsed = num.tryParse(text);
    if (parsed == null) return text;
    return parsed.toInt().toString();
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    return (raw as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw mapFailure(error);
    }
  }
}
