import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../domain/service_repository.dart';

class SupabaseServiceRepository implements ServiceRepository {
  SupabaseServiceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ServiceListItem>> board(String venueId) {
    return _guard(() async {
      final raw = await _client.rpc('service_board', params: {'p_venue_id': venueId});
      return _list(raw).map((row) {
        return ServiceListItem(
          listId: row['list_id'] as String,
          listName: row['list_name'] as String,
          published: row['published'] == true,
          listItemId: row['list_item_id'] as String,
          itemId: row['item_id'] as String,
          sku: row['sku'] as String? ?? '',
          label: row['label'] as String? ?? '',
          pourMl: row['pour_ml'] as int?,
          manual86: row['manual_86'] == true,
          houseBottles: _whole(row['house_bottles']),
          openRemainingMl: int.tryParse(row['open_remaining_ml'].toString()) ?? 0,
          available: row['available'] == true,
          unavailableReason: row['unavailable_reason'] as String?,
        );
      }).toList();
    });
  }

  @override
  Future<List<OpenBottleRecord>> openBottles(String venueId) {
    return _guard(() async {
      final rows = _list(
        await _client
            .from('open_bottles')
            .select('id, item_id, remaining_ml, opened_ml, status')
            .eq('venue_id', venueId)
            .eq('status', 'open'),
      );
      return [
        for (final row in rows)
          OpenBottleRecord(
            id: row['id'] as String,
            itemId: row['item_id'] as String,
            remainingMl: row['remaining_ml'] as int,
            openedMl: row['opened_ml'] as int,
          ),
      ];
    });
  }

  @override
  Future<String> createList({
    required String organizationId,
    required String venueId,
    required String name,
    required String kind,
    required int threshold,
  }) {
    return _guard(() async {
      final id = await _client.rpc(
        'create_wine_list',
        params: {
          'p_organization_id': organizationId,
          'p_venue_id': venueId,
          'p_name': name,
          'p_kind': kind,
          'p_threshold': threshold,
        },
      );
      return id.toString();
    });
  }

  @override
  Future<void> addItem({required String listId, required String itemId, int? pourMl}) {
    return _guard(
      () => _client.rpc(
        'add_wine_list_item',
        params: {'p_list_id': listId, 'p_item_id': itemId, 'p_pour_ml': pourMl},
      ),
    );
  }

  @override
  Future<void> publish({required String listId, required bool published}) {
    return _guard(
      () => _client.rpc(
        'publish_wine_list',
        params: {'p_list_id': listId, 'p_published': published},
      ),
    );
  }

  @override
  Future<void> set86({required String listItemId, required bool eightySixed}) {
    return _guard(
      () => _client.rpc(
        'set_wine_86',
        params: {'p_list_item_id': listItemId, 'p_eighty_sixed': eightySixed},
      ),
    );
  }

  @override
  Future<void> openBottle({required String venueId, required String itemId}) {
    return _guard(
      () => _client.rpc(
        'open_service_bottle',
        params: {'p_venue_id': venueId, 'p_item_id': itemId},
      ),
    );
  }

  @override
  Future<int> pour({
    required String openBottleId,
    required int pourMl,
    required String reason,
  }) {
    return _guard(() async {
      final left = await _client.rpc(
        'record_pour',
        params: {
          'p_open_bottle_id': openBottleId,
          'p_pour_ml': pourMl,
          'p_reason': reason,
        },
      );
      return int.tryParse(left.toString()) ?? 0;
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
