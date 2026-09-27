import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../domain/allocation_repository.dart';

class SupabaseAllocationRepository implements AllocationRepository {
  SupabaseAllocationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ClubMember>> members(String organizationId) {
    return _guard(() async {
      final rows = _list(
        await _client
            .from('wine_club_members')
            .select('id, display_name, tier')
            .eq('organization_id', organizationId)
            .eq('active', true),
      );
      return [
        for (final row in rows)
          ClubMember(
            id: row['id'] as String,
            name: row['display_name'] as String,
            tier: row['tier'] as String,
          ),
      ];
    });
  }

  @override
  Future<List<AllocationCampaign>> campaigns(String venueId) {
    return _guard(() async {
      final raw = await _client.rpc('list_allocation_campaigns', params: {'p_venue_id': venueId});
      return _list(raw).map((row) {
        return AllocationCampaign(
          id: row['id'] as String,
          name: row['name'] as String,
          releaseOn: row['release_on'].toString(),
          status: row['status'] as String,
          lineCount: int.tryParse(row['line_count'].toString()) ?? 0,
        );
      }).toList();
    });
  }

  @override
  Future<void> createMember({
    required String organizationId,
    required String name,
    required String tier,
  }) {
    return _guard(
      () => _client.rpc(
        'create_club_member',
        params: {
          'p_organization_id': organizationId,
          'p_display_name': name,
          'p_tier': tier,
        },
      ),
    );
  }

  @override
  Future<String> createCampaign({
    required String organizationId,
    required String venueId,
    required String name,
    required String releaseOn,
  }) {
    return _guard(() async {
      final id = await _client.rpc(
        'create_allocation_campaign',
        params: {
          'p_organization_id': organizationId,
          'p_venue_id': venueId,
          'p_name': name,
          'p_release_on': releaseOn,
        },
      );
      return id.toString();
    });
  }

  @override
  Future<void> addLine({
    required String campaignId,
    required String memberId,
    required String itemId,
    required String quantity,
  }) {
    return _guard(
      () => _client.rpc(
        'add_allocation_line',
        params: {
          'p_campaign_id': campaignId,
          'p_member_id': memberId,
          'p_item_id': itemId,
          'p_quantity': quantity,
        },
      ),
    );
  }

  @override
  Future<int> reserve(String campaignId) {
    return _guard(() async {
      final holds = await _client.rpc('reserve_allocation', params: {'p_campaign_id': campaignId});
      return int.tryParse(holds.toString()) ?? 0;
    });
  }

  @override
  Future<void> pickup({required String lineId, required String quantity}) {
    return _guard(
      () => _client.rpc(
        'fulfill_allocation_pickup',
        params: {'p_line_id': lineId, 'p_quantity': quantity},
      ),
    );
  }

  @override
  Future<List<AllocationReadinessLine>> readiness(String campaignId) {
    return _guard(() async {
      final raw = await _client.rpc('allocation_readiness', params: {'p_campaign_id': campaignId});
      return _list(raw).map((row) {
        return AllocationReadinessLine(
          lineId: row['line_id'] as String,
          memberName: row['member_name'] as String,
          sku: row['sku'] as String? ?? '',
          label: row['label'] as String? ?? '',
          required: _whole(row['quantity_required']),
          reserved: _whole(row['quantity_reserved']),
          fulfilled: _whole(row['quantity_fulfilled']),
          houseAvailable: _whole(row['house_available']),
          shortage: _whole(row['shortage']),
          status: row['status'] as String,
        );
      }).toList();
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
