import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/count_rules.dart';

class CountDraftStore {
  CountDraftStore(this._preferences, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const draftsKey = 'vw.count_drafts.v1';
  static const syncKey = 'vw.count_sync_at';

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

  List<CountDraft> _read() {
    final raw = _preferences.getString(draftsKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => CountDraft.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
