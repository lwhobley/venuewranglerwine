import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../domain/cellar_repository.dart';
import '../domain/cellar_rules.dart';

class SupabaseCellarRepository implements CellarRepository {
  SupabaseCellarRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CellarSnapshot> load({required String organizationId, required String venueId}) {
    return _guard(() async {
      final locations = _list(
        await _client
            .from('storage_locations')
            .select('id, kind, name, code, parent_id')
            .eq('venue_id', venueId),
      );
      final templates = _list(
        await _client
            .from('storage_unit_templates')
            .select('key, label, default_rows, default_columns, slot_capacity'),
      );
      final units = _list(
        await _client
            .from('storage_units')
            .select('id, location_id, name, code, template_key')
            .eq('venue_id', venueId),
      );
      final slots = _list(
        await _client
            .from('storage_slots')
            .select('id, unit_id, location_code, capacity_bottles')
            .eq('venue_id', venueId),
      );
      final profiles = _list(
        await _client
            .from('inventory_items')
            .select('id, sku, name, wine_profiles(producer, cuvee, wine_type, vintage, bottle_ml)')
            .eq('organization_id', organizationId),
      );
      final vendors = _list(
        await _client
            .from('vendors')
            .select('id, name')
            .eq('organization_id', organizationId)
            .eq('active', true),
      );
      final balances = _list(
        await _client
            .from('inventory_balances')
            .select('lot_id, item_id, location_id, slot_id, quantity')
            .eq('venue_id', venueId)
            .eq('ownership_class', 'house'),
      );
      final staging = locations.where((row) => row['kind'] == 'staging').firstOrNull;
      final wines = profiles.map(_wine).toList();
      final byItem = {for (final wine in wines) wine.itemId: wine.label};
      final slotQty = <String, num>{};
      final staged = <StagedLot>[];
      for (final balance in balances) {
        final quantity = num.tryParse(balance['quantity'].toString()) ?? 0;
        if (quantity <= 0) continue;
        final slotId = balance['slot_id'] as String?;
        if (slotId != null) {
          slotQty[slotId] = (slotQty[slotId] ?? 0) + quantity;
          continue;
        }
        if (staging != null && balance['location_id'] == staging['id']) {
          final itemId = balance['item_id'] as String;
          staged.add(
            StagedLot(
              lotId: balance['lot_id'] as String,
              itemId: itemId,
              quantity: _whole(balance['quantity']),
              label: byItem[itemId] ?? itemId,
            ),
          );
        }
      }
      return CellarSnapshot(
        rooms: [
          for (final row in locations)
            CellarRoom(
              id: row['id'] as String,
              name: row['name'] as String,
              code: row['code'] as String,
              kind: row['kind'] as String,
              parentId: row['parent_id'] as String?,
            ),
        ],
        templates: [
          for (final row in templates)
            RackTemplate(
              key: row['key'] as String,
              label: row['label'] as String,
              rows: row['default_rows'] as int,
              columns: row['default_columns'] as int,
              slotCapacity: row['slot_capacity'] as int,
            ),
        ],
        units: [
          for (final row in units)
            StorageUnitRecord(
              id: row['id'] as String,
              locationId: row['location_id'] as String,
              name: row['name'] as String,
              code: row['code'] as String,
              templateKey: row['template_key'] as String,
            ),
        ],
        slots: [
          for (final row in slots)
            StorageSlotRecord(
              id: row['id'] as String,
              unitId: row['unit_id'] as String,
              locationCode: row['location_code'] as String,
              capacityBottles: row['capacity_bottles'] as int,
              onHand: _whole(slotQty[row['id']] ?? 0),
            ),
        ],
        wines: wines,
        vendors: [
          for (final row in vendors)
            VendorRecord(id: row['id'] as String, name: row['name'] as String),
        ],
        staged: staged,
        stagingId: staging?['id'] as String?,
      );
    });
  }

  @override
  Future<void> createRoom({
    required String organizationId,
    required String venueId,
    required String name,
    required String code,
  }) {
    return _guard(
      () => _client.rpc(
        'create_cellar_room',
        params: {
          'p_organization_id': organizationId,
          'p_venue_id': venueId,
          'p_name': name,
          'p_code': code,
        },
      ),
    );
  }

  @override
  Future<void> placeUnit({
    required String organizationId,
    required String venueId,
    required String locationId,
    required String templateKey,
    required String name,
    required String code,
  }) {
    return _guard(
      () => _client.rpc(
        'place_storage_unit',
        params: {
          'p_organization_id': organizationId,
          'p_venue_id': venueId,
          'p_location_id': locationId,
          'p_template_key': templateKey,
          'p_name': name,
          'p_code': code,
        },
      ),
    );
  }

  @override
  Future<void> createVendor({
    required String organizationId,
    required String name,
    String? email,
  }) {
    return _guard(
      () => _client.rpc(
        'create_vendor',
        params: {
          'p_organization_id': organizationId,
          'p_name': name,
          'p_email': email,
        },
      ),
    );
  }

  @override
  Future<WineImportResult> importWines({
    required String organizationId,
    required List<WineImportRow> rows,
  }) {
    return _guard(() async {
      final raw = await _client.rpc(
        'import_wines',
        params: {
          'p_organization_id': organizationId,
          'p_rows': rows.map((row) => row.toJson()).toList(),
        },
      );
      final map = Map<String, dynamic>.from(raw as Map);
      final errors = (map['errors'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map((item) => 'Line ${item['line']}: ${item['message']}')
          .toList();
      return WineImportResult(
        imported: map['imported'] as int? ?? 0,
        updated: map['updated'] as int? ?? 0,
        errors: errors,
      );
    });
  }

  @override
  Future<void> receive({
    required String organizationId,
    required String venueId,
    required String vendorId,
    required String itemId,
    required String quantity,
    required String unitCost,
  }) {
    return _guard(
      () => _client.rpc(
        'receive_to_staging',
        params: {
          'p_organization_id': organizationId,
          'p_venue_id': venueId,
          'p_vendor_id': vendorId,
          'p_item_id': itemId,
          'p_quantity': quantity,
          'p_unit_cost': unitCost,
        },
      ),
    );
  }

  @override
  Future<void> putAway({
    required String organizationId,
    required String venueId,
    required String lotId,
    required String slotId,
    required String quantity,
  }) {
    return _guard(
      () => _client.rpc(
        'put_away',
        params: {
          'p_organization_id': organizationId,
          'p_venue_id': venueId,
          'p_lot_id': lotId,
          'p_slot_id': slotId,
          'p_quantity': quantity,
        },
      ),
    );
  }

  WineRecord _wine(Map<String, dynamic> row) {
    final profile = row['wine_profiles'] == null
        ? null
        : Map<String, dynamic>.from(row['wine_profiles'] as Map);
    return WineRecord(
      itemId: row['id'] as String,
      sku: row['sku'] as String,
      producer: profile?['producer'] as String? ?? '',
      cuvee: profile?['cuvee'] as String? ?? '',
      wineType: profile?['wine_type'] as String? ?? 'inventory',
      bottleMl: profile?['bottle_ml'] as int? ?? 0,
      vintage: profile?['vintage'] as int?,
      catalogName: profile == null ? row['name'] as String : null,
    );
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
