import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../domain/movement_repository.dart';

class SupabaseMovementRepository implements MovementRepository {
  SupabaseMovementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MovableLot>> movable(String venueId) {
    return _guard(() async {
      final balances = _list(
        await _client
            .from('inventory_balances')
            .select('lot_id, item_id, slot_id, quantity')
            .eq('venue_id', venueId)
            .eq('ownership_class', 'house'),
      );
      final slots = _list(
        await _client.from('storage_slots').select('id, location_code').eq('venue_id', venueId),
      );
      final profiles = _list(
        await _client.from('wine_profiles').select('item_id, producer, cuvee, vintage'),
      );
      final slotCode = {for (final row in slots) row['id'] as String: row['location_code'] as String};
      final labels = {
        for (final row in profiles)
          row['item_id'] as String:
              '${row['producer']} ${row['cuvee']}${row['vintage'] == null ? ' NV' : ' ${row['vintage']}'}',
      };
      return [
        for (final row in balances)
          if (row['slot_id'] != null && _whole(row['quantity']) != '0')
            MovableLot(
              lotId: row['lot_id'] as String,
              slotId: row['slot_id'] as String,
              locationCode: slotCode[row['slot_id']] ?? '',
              label: labels[row['item_id']] ?? 'Wine',
              quantity: _whole(row['quantity']),
            ),
      ];
    });
  }

  @override
  Future<List<ServiceLocation>> destinations(String venueId) {
    return _guard(() async {
      final rows = _list(
        await _client
            .from('storage_locations')
            .select('id, kind, name, code, holder_label')
            .eq('venue_id', venueId)
            .inFilter('kind', ['service_bar', 'event_staging', 'member_locker']),
      );
      return [
        for (final row in rows)
          ServiceLocation(
            id: row['id'] as String,
            kind: row['kind'] as String,
            name: row['name'] as String,
            code: row['code'] as String,
            holderLabel: row['holder_label'] as String?,
          ),
      ];
    });
  }

  @override
  Future<List<TransferRecord>> recent(String venueId) {
    return _guard(() async {
      final raw = await _client.rpc('recent_transfers', params: {'p_venue_id': venueId});
      return _list(raw).map((row) {
        return TransferRecord(
          id: row['id'] as String,
          reason: row['reason'] as String,
          quantity: _whole(row['quantity']),
          sourceCode: row['source_code'] as String? ?? '',
          destinationName: row['destination_name'] as String? ?? '',
          sourceBefore: _whole(row['source_before']),
          sourceAfter: _whole(row['source_after']),
          createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
        );
      }).toList();
    });
  }

  @override
  Future<void> createDestination({
    required String organizationId,
    required String venueId,
    required String kind,
    required String name,
    required String code,
    String? holderLabel,
  }) {
    return _guard(
      () => _client.rpc(
        'create_service_location',
        params: {
          'p_organization_id': organizationId,
          'p_venue_id': venueId,
          'p_kind': kind,
          'p_name': name,
          'p_code': code,
          'p_holder_label': holderLabel,
        },
      ),
    );
  }

  @override
  Future<TransferResult> transfer({
    required String organizationId,
    required String venueId,
    required String lotId,
    required String sourceSlotId,
    required String destinationLocationId,
    required String quantity,
  }) {
    return _guard(() async {
      final raw = await _client.rpc(
        'transfer_inventory',
        params: {
          'p_organization_id': organizationId,
          'p_venue_id': venueId,
          'p_lot_id': lotId,
          'p_source_slot_id': sourceSlotId,
          'p_destination_location_id': destinationLocationId,
          'p_quantity': quantity,
        },
      );
      final map = Map<String, dynamic>.from(raw as Map);
      return TransferResult(
        movementId: map['movement_id'].toString(),
        sourceBefore: _whole(map['source_before']),
        sourceAfter: _whole(map['source_after']),
        destinationBefore: _whole(map['destination_before']),
        destinationAfter: _whole(map['destination_after']),
        reason: map['reason'] as String,
      );
    });
  }

  String _whole(Object? value) {
    final parsed = num.tryParse(value.toString()) ?? 0;
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
