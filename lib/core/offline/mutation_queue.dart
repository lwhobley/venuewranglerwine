import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class QueuedMutation {
  const QueuedMutation({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });

  final String id;
  final String kind;
  final Map<String, String> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'kind': kind,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts,
      'lastError': lastError,
    };
  }

  factory QueuedMutation.fromJson(Map<String, dynamic> json) {
    return QueuedMutation(
      id: json['id'] as String,
      kind: json['kind'] as String,
      payload: Map<String, String>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}

abstract interface class MutationQueue {
  Future<List<QueuedMutation>> pending({String? kind});
  Future<QueuedMutation> enqueue({
    required String kind,
    required Map<String, String> payload,
  });
  Future<void> remove(String id);
  Future<void> markFailed(String id, String message);
}

class SharedPreferencesMutationQueue implements MutationQueue {
  SharedPreferencesMutationQueue(this._preferences, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const storageKey = 'vw.mutation_queue.v1';

  final SharedPreferences _preferences;
  final Uuid _uuid;

  @override
  Future<List<QueuedMutation>> pending({String? kind}) async {
    final all = _read();
    if (kind == null) return all;
    return all.where((item) => item.kind == kind).toList();
  }

  @override
  Future<QueuedMutation> enqueue({
    required String kind,
    required Map<String, String> payload,
  }) async {
    final item = QueuedMutation(
      id: _uuid.v4(),
      kind: kind,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
      attempts: 0,
    );
    final next = [..._read(), item];
    await _write(next);
    return item;
  }

  @override
  Future<void> remove(String id) async {
    await _write(_read().where((item) => item.id != id).toList());
  }

  @override
  Future<void> markFailed(String id, String message) async {
    final next = _read().map((item) {
      if (item.id != id) return item;
      return QueuedMutation(
        id: item.id,
        kind: item.kind,
        payload: item.payload,
        createdAt: item.createdAt,
        attempts: item.attempts + 1,
        lastError: message,
      );
    }).toList();
    await _write(next);
  }

  List<QueuedMutation> _read() {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => QueuedMutation.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> _write(List<QueuedMutation> items) {
    return _preferences.setString(
      storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}

final mutationQueueProvider = FutureProvider<MutationQueue>((ref) async {
  final preferences = await SharedPreferences.getInstance();
  return SharedPreferencesMutationQueue(preferences);
});
