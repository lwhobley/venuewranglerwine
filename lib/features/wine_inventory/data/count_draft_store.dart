import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/count_repository.dart';
import '../domain/count_rules.dart';

class CountDraftStore {
  CountDraftStore(this._preferences, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const draftsKey = 'vw.count_drafts.v1';
  static const syncKey = 'vw.count_sync_at';
  static const lotsKey = 'vw.count_lots.v1';

  final SharedPreferences _preferences;
  final Uuid _uuid;

  String newEntryId() => _uuid.v4();

  List<CountDraft> draftsFor(String sessionId) {
    return _read().where((draft) => draft.sessionId == sessionId).toList();
  }

  Future<CountDraft> save(CountDraft draft) async {
    final next = [
      for (final existing in _read())
        if (existing.clientEntryId != draft.clientEntryId) existing,
      draft,
    ];
    await _preferences.setString(draftsKey, jsonEncode(next.map((item) => item.toJson()).toList()));
    return draft;
  }

  Future<void> markSynced(DateTime at) {
    return _preferences.setString(syncKey, at.toUtc().toIso8601String());
  }

  DateTime? lastSync() {
    final raw = _preferences.getString(syncKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.parse(raw);
  }

  Future<void> saveLotChoices({
    required String sessionId,
    required String locationCode,
    required String sku,
    required List<String> lotIds,
  }) async {
    final next = _lots();
    next[_lotKey(sessionId, locationCode, sku)] = lotIds;
    await _preferences.setString(lotsKey, jsonEncode(next));
  }

  Future<void> rememberSheetLots(String sessionId, List<CountSheetLine> sheet) async {
    final next = _lots();
    final grouped = <String, List<String>>{};
    for (final line in sheet) {
      final lotId = line.lotId;
      if (lotId == null || line.sku.isEmpty) continue;
      grouped.putIfAbsent(_lotKey(sessionId, line.locationCode, line.sku), () => []).add(lotId);
    }
    next.addAll(grouped);
    await _preferences.setString(lotsKey, jsonEncode(next));
  }

  List<String>? cachedLotIds({
    required String sessionId,
    required String locationCode,
    required String sku,
  }) {
    final lots = _lots()[_lotKey(sessionId, locationCode, sku)];
    return lots == null ? null : List<String>.from(lots);
  }

  String _lotKey(String sessionId, String locationCode, String sku) {
    return '$sessionId|${locationCode.toUpperCase()}|${sku.toUpperCase()}';
  }

  Map<String, List<String>> _lots() {
    final raw = _preferences.getString(lotsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, List<String>.from(value as List)));
  }

  List<CountDraft> _read() {
    final raw = _preferences.getString(draftsKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => CountDraft.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
