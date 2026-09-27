import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../data/count_draft_store.dart';
import '../data/supabase_count_repository.dart';
import '../domain/count_repository.dart';
import '../domain/count_rules.dart';

final countRepositoryProvider = Provider<CountRepository>((ref) {
  return SupabaseCountRepository(Supabase.instance.client);
});

final countDraftStoreProvider = FutureProvider<CountDraftStore>((ref) async {
  final preferences = await SharedPreferences.getInstance();
  return CountDraftStore(preferences);
});

final countSessionsProvider = AsyncNotifierProvider<CountSessionsController, List<CountSessionSummary>>(
  CountSessionsController.new,
);

class CountSessionsController extends AsyncNotifier<List<CountSessionSummary>> {
  @override
  Future<List<CountSessionSummary>> build() async {
    final venueId = ref.watch(workspaceControllerProvider).venueId;
    if (venueId == null) return const [];
    return ref.read(countRepositoryProvider).listSessions(venueId);
  }

  Future<String> start({required String kind, required String mode, String? locationId}) async {
    final selection = ref.read(workspaceControllerProvider);
    final id = await ref.read(countRepositoryProvider).startSession(
      organizationId: selection.organizationId!,
      venueId: selection.venueId!,
      kind: kind,
      mode: mode,
      locationId: locationId,
    );
    ref.invalidateSelf();
    return id;
  }
}

class CountDesk {
  const CountDesk({
    required this.drafts,
    required this.sheet,
    required this.lastSync,
  });

  final List<CountDraft> drafts;
  final List<CountSheetLine> sheet;
  final DateTime? lastSync;
}

final countDeskProvider = AsyncNotifierProvider.family<CountDeskController, CountDesk, String>(
  CountDeskController.new,
);

class CountDeskController extends AsyncNotifier<CountDesk> {
  CountDeskController(this.sessionId);

  final String sessionId;

  @override
  Future<CountDesk> build() async {
    final store = await ref.watch(countDraftStoreProvider.future);
    List<CountSheetLine> sheet = const [];
    try {
      sheet = await ref.read(countRepositoryProvider).sheet(sessionId);
    } on NetworkFailure {
      sheet = const [];
    }
    return CountDesk(
      drafts: store.draftsFor(sessionId),
      sheet: sheet,
      lastSync: store.lastSync(),
    );
  }

  Future<void> saveLocal({
    required String locationCode,
    required String sku,
    required String quantity,
    required String reason,
  }) async {
    final store = await ref.read(countDraftStoreProvider.future);
    final parsed = parseLocationScan(locationCode);
    if (parsed == null) {
      throw const ValidationFailure('Enter a location code, or the code from its label.');
    }
    await store.save(
      CountDraft(
        clientEntryId: store.newEntryId(),
        sessionId: sessionId,
        locationCode: parsed,
        sku: sku.trim().toUpperCase(),
        quantity: quantity.trim(),
        reason: reason.trim(),
        syncStatus: 'pending',
      ),
    );
    ref.invalidateSelf();
  }

  Future<int> sync() async {
    final store = await ref.read(countDraftStoreProvider.future);
    final repository = ref.read(countRepositoryProvider);
    var sent = 0;
    for (final draft in store.draftsFor(sessionId).where((item) => item.syncStatus != 'synced')) {
      try {
        final result = await repository.recordEntry(
          sessionId: sessionId,
          clientEntryId: draft.clientEntryId,
          locationCode: draft.locationCode,
          sku: draft.sku,
          quantity: draft.quantity,
          reason: draft.reason,
        );
        await store.save(
          draft.copyWith(
            syncStatus: result.isConflict ? 'conflict' : 'synced',
            message: result.isConflict ? 'Another counter already entered this slot.' : null,
          ),
        );
        if (!result.isConflict) sent += 1;
      } on NetworkFailure {
        break;
      } catch (error) {
        final message = error is AppFailure ? error.message : mapFailure(error).message;
        await store.save(draft.copyWith(syncStatus: 'failed', message: message));
      }
    }
    await store.markSynced(DateTime.now().toUtc());
    ref.invalidateSelf();
    return sent;
  }

  Future<void> submit() async {
    await sync();
    final store = await ref.read(countDraftStoreProvider.future);
    final unresolved = store.draftsFor(sessionId).where((draft) => draft.syncStatus != 'synced');
    if (unresolved.isNotEmpty) {
      throw const ValidationFailure('Resolve every local count entry before submitting.');
    }
    await ref.read(countRepositoryProvider).submit(sessionId);
    ref.invalidate(countSessionsProvider);
    ref.invalidateSelf();
  }

  Future<int> approve() async {
    final written = await ref.read(countRepositoryProvider).approve(sessionId);
    ref.invalidate(countSessionsProvider);
    ref.invalidateSelf();
    return written;
  }

  Future<void> reject() async {
    await ref.read(countRepositoryProvider).reject(sessionId);
    ref.invalidate(countSessionsProvider);
    ref.invalidateSelf();
  }

  Future<void> resolve({required String lineId, required String quantity}) async {
    await ref.read(countRepositoryProvider).resolveConflict(lineId: lineId, quantity: quantity);
    ref.invalidateSelf();
  }
}
