import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';

class SupabaseOpsRepository {
  SupabaseOpsRepository(this._client);

  final SupabaseClient _client;

  Future<String> createGuest({
    required String organizationId,
    required String venueId,
    required String name,
    required String allergies,
    required String seating,
    required bool vip,
  }) {
    return _id('create_guest', {
      'p_organization_id': organizationId,
      'p_venue_id': venueId,
      'p_name': name,
      'p_allergies': allergies,
      'p_seating': seating,
      'p_vip': vip,
    });
  }

  Future<void> setFavorite({required String guestId, required String itemId}) {
    return _guard(() => _client.rpc('set_guest_favorite', params: {
      'p_guest_id': guestId,
      'p_item_id': itemId,
    }));
  }

  Future<String> createTable({
    required String organizationId,
    required String venueId,
    required String label,
    required int capacity,
  }) {
    return _id('create_floor_table', {
      'p_organization_id': organizationId,
      'p_venue_id': venueId,
      'p_label': label,
      'p_capacity': capacity,
    });
  }

  Future<String> createReservation({
    required String organizationId,
    required String venueId,
    required String guestId,
    required int partySize,
    required DateTime reservedAt,
  }) {
    return _id('create_reservation', {
      'p_organization_id': organizationId,
      'p_venue_id': venueId,
      'p_guest_id': guestId,
      'p_party_size': partySize,
      'p_reserved_at': reservedAt.toUtc().toIso8601String(),
      'p_notes': '',
    });
  }

  Future<void> seat({required String reservationId, required String tableId}) {
    return _guard(() => _client.rpc('seat_reservation', params: {
      'p_reservation_id': reservationId,
      'p_table_id': tableId,
    }));
  }

  Future<void> completeReservation(String reservationId) {
    return _guard(() => _client.rpc('complete_reservation', params: {'p_reservation_id': reservationId}));
  }

  Future<void> clearTable(String tableId) {
    return _guard(() => _client.rpc('clear_table', params: {'p_table_id': tableId}));
  }

  Future<List<Map<String, dynamic>>> hostBoard(String venueId) => _rows('host_board', {'p_venue_id': venueId});

  Future<List<Map<String, dynamic>>> guests(String venueId) {
    return _guard(() async => _list(await _client.from('guests').select('id, display_name').eq('venue_id', venueId)));
  }

  Future<List<Map<String, dynamic>>> tables(String venueId) {
    return _guard(() async => _list(await _client.from('floor_tables').select('id, label, capacity, status').eq('venue_id', venueId)));
  }

  Future<String> createShift({
    required String organizationId,
    required String venueId,
    required String roleKey,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    return _id('create_shift', {
      'p_organization_id': organizationId,
      'p_venue_id': venueId,
      'p_role_key': roleKey,
      'p_starts_at': startsAt.toUtc().toIso8601String(),
      'p_ends_at': endsAt.toUtc().toIso8601String(),
    });
  }

  Future<int> publishShifts(String venueId) => _int('publish_shifts', {'p_venue_id': venueId});

  Future<void> clockIn(String venueId) => _guard(() => _client.rpc('clock_in', params: {'p_venue_id': venueId}));

  Future<void> clockOut(String venueId) => _guard(() => _client.rpc('clock_out', params: {'p_venue_id': venueId}));

  Future<String> createChecklist({
    required String organizationId,
    required String venueId,
    required String name,
    required String itemLabel,
  }) {
    return _id('create_checklist', {
      'p_organization_id': organizationId,
      'p_venue_id': venueId,
      'p_name': name,
      'p_item_label': itemLabel,
    });
  }

  Future<String> startChecklist(String templateId) => _id('start_checklist_run', {'p_template_id': templateId});

  Future<void> completeItem({required String runId, required String itemId}) {
    return _guard(() => _client.rpc('complete_checklist_item', params: {'p_run_id': runId, 'p_item_id': itemId}));
  }

  Future<void> writeLog(String venueId, String body) {
    return _guard(() => _client.rpc('write_logbook', params: {'p_venue_id': venueId, 'p_body': body}));
  }

  Future<String> createDocument({
    required String organizationId,
    required String venueId,
    required String title,
    required String body,
  }) {
    return _id('create_document', {
      'p_organization_id': organizationId,
      'p_venue_id': venueId,
      'p_title': title,
      'p_body': body,
    });
  }

  Future<void> acknowledge(String documentId) {
    return _guard(() => _client.rpc('acknowledge_document', params: {'p_document_id': documentId}));
  }

  Future<List<Map<String, dynamic>>> shifts(String venueId) {
    return _guard(() async => _list(await _client.from('shifts').select('id, role_key, starts_at, ends_at, status').eq('venue_id', venueId)));
  }

  Future<List<Map<String, dynamic>>> openClock(String venueId, String userId) {
    return _guard(() async => _list(
      await _client.from('time_entries').select('id, clock_in, clock_out').eq('venue_id', venueId).eq('user_id', userId).isFilter('clock_out', null),
    ));
  }

  Future<List<Map<String, dynamic>>> checklistTemplates(String venueId) {
    return _guard(() async => _list(await _client.from('checklist_templates').select('id, name').eq('venue_id', venueId)));
  }

  Future<List<Map<String, dynamic>>> checklistItems(String templateId) {
    return _guard(() async => _list(await _client.from('checklist_items').select('id, label').eq('template_id', templateId)));
  }

  Future<List<Map<String, dynamic>>> openRuns(String venueId) {
    return _guard(() async => _list(await _client.from('checklist_runs').select('id, template_id, status').eq('venue_id', venueId).eq('status', 'open')));
  }

  Future<List<Map<String, dynamic>>> logbook(String venueId) {
    return _guard(() async => _list(await _client.from('logbook_entries').select('id, body, created_at').eq('venue_id', venueId).order('created_at', ascending: false).limit(8)));
  }

  Future<List<Map<String, dynamic>>> documents(String venueId) {
    return _guard(() async => _list(await _client.from('documents').select('id, title, requires_ack').eq('venue_id', venueId)));
  }

  Future<String> createEvent({
    required String organizationId,
    required String venueId,
    required String name,
    required int guestCount,
    required DateTime startsAt,
  }) {
    return _id('create_event', {
      'p_organization_id': organizationId,
      'p_venue_id': venueId,
      'p_name': name,
      'p_guest_count': guestCount,
      'p_starts_at': startsAt.toUtc().toIso8601String(),
    });
  }

  Future<String> advanceEvent(String eventId) {
    return _guard(() async => (await _client.rpc('advance_event', params: {'p_event_id': eventId})).toString());
  }

  Future<int> addBeo({required String eventId, required String body}) => _int('add_beo', {'p_event_id': eventId, 'p_body': body});

  Future<String> createChannel({required String venueId, required String name}) {
    return _id('create_channel', {'p_venue_id': venueId, 'p_name': name});
  }

  Future<void> postMessage({required String channelId, required String body}) {
    return _guard(() => _client.rpc('post_message', params: {'p_channel_id': channelId, 'p_body': body}));
  }

  Future<void> saveIntegration({required String organizationId, required String providerKey, required String status}) {
    return _guard(() => _client.rpc('save_integration', params: {
      'p_organization_id': organizationId,
      'p_provider_key': providerKey,
      'p_status': status,
    }));
  }

  Future<List<Map<String, dynamic>>> report(String venueId) => _rows('operational_report', {'p_venue_id': venueId});

  Future<List<Map<String, dynamic>>> events(String venueId) {
    return _guard(() async => _list(await _client.from('events').select('id, name, stage, guest_count').eq('venue_id', venueId)));
  }

  Future<List<Map<String, dynamic>>> beos(String eventId) {
    return _guard(() async => _list(await _client.from('beo_versions').select('version_number, body').eq('event_id', eventId).order('version_number')));
  }

  Future<List<Map<String, dynamic>>> channels(String venueId) {
    return _guard(() async => _list(await _client.from('channels').select('id, name').eq('venue_id', venueId)));
  }

  Future<List<Map<String, dynamic>>> messages(String channelId) {
    return _guard(() async => _list(await _client.from('messages').select('body, created_at').eq('channel_id', channelId).order('created_at')));
  }

  Future<String> _id(String fn, Map<String, Object?> params) {
    return _guard(() async => (await _client.rpc(fn, params: params)).toString());
  }

  Future<int> _int(String fn, Map<String, Object?> params) {
    return _guard(() async => int.tryParse((await _client.rpc(fn, params: params)).toString()) ?? 0);
  }

  Future<List<Map<String, dynamic>>> _rows(String fn, Map<String, Object?> params) {
    return _guard(() async => _list(await _client.rpc(fn, params: params)));
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
