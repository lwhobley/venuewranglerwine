import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/application/workspace_controller.dart';
import '../data/supabase_cellar_repository.dart';
import '../domain/cellar_repository.dart';
import '../domain/cellar_rules.dart';

final cellarRepositoryProvider = Provider<CellarRepository>((ref) {
  return SupabaseCellarRepository(Supabase.instance.client);
});

final cellarControllerProvider = AsyncNotifierProvider<CellarController, CellarSnapshot>(
  CellarController.new,
);

class CellarController extends AsyncNotifier<CellarSnapshot> {
  @override
  Future<CellarSnapshot> build() async {
    final selection = ref.watch(workspaceControllerProvider);
    if (selection.venueId == null || selection.organizationId == null) {
      return CellarSnapshot.empty;
    }
    return ref.read(cellarRepositoryProvider).load(
      organizationId: selection.organizationId!,
      venueId: selection.venueId!,
    );
  }

  Future<void> refresh() async {
    final selection = ref.read(workspaceControllerProvider);
    if (selection.venueId == null || selection.organizationId == null) {
      state = const AsyncData(CellarSnapshot.empty);
      return;
    }
    state = await AsyncValue.guard(
      () => ref.read(cellarRepositoryProvider).load(
        organizationId: selection.organizationId!,
        venueId: selection.venueId!,
      ),
    );
  }

  Future<void> createRoom({required String name, required String code}) async {
    final scope = _scope();
    await ref.read(cellarRepositoryProvider).createRoom(
      organizationId: scope.$1,
      venueId: scope.$2,
      name: name,
      code: code,
    );
    await refresh();
  }

  Future<void> placeUnit({
    required String locationId,
    required String templateKey,
    required String name,
    required String code,
  }) async {
    final scope = _scope();
    await ref.read(cellarRepositoryProvider).placeUnit(
      organizationId: scope.$1,
      venueId: scope.$2,
      locationId: locationId,
      templateKey: templateKey,
      name: name,
      code: code,
    );
    await refresh();
  }

  Future<void> createVendor({required String name, String? email}) async {
    final scope = _scope();
    await ref.read(cellarRepositoryProvider).createVendor(
      organizationId: scope.$1,
      name: name,
      email: email,
    );
    await refresh();
  }

  Future<WineImportResult> importWines(List<WineImportRow> rows) async {
    final scope = _scope();
    final result = await ref.read(cellarRepositoryProvider).importWines(
      organizationId: scope.$1,
      rows: rows,
    );
    await refresh();
    return result;
  }

  Future<void> receive({
    required String vendorId,
    required String itemId,
    required String quantity,
    required String unitCost,
  }) async {
    final scope = _scope();
    await ref.read(cellarRepositoryProvider).receive(
      organizationId: scope.$1,
      venueId: scope.$2,
      vendorId: vendorId,
      itemId: itemId,
      quantity: quantity,
      unitCost: unitCost,
    );
    await refresh();
  }

  Future<void> putAway({
    required String lotId,
    required String slotId,
    required String quantity,
  }) async {
    final scope = _scope();
    await ref.read(cellarRepositoryProvider).putAway(
      organizationId: scope.$1,
      venueId: scope.$2,
      lotId: lotId,
      slotId: slotId,
      quantity: quantity,
    );
    await refresh();
  }

  (String, String) _scope() {
    final selection = ref.read(workspaceControllerProvider);
    final organizationId = selection.organizationId;
    final venueId = selection.venueId;
    if (organizationId == null || venueId == null) {
      throw StateError('venue_not_found');
    }
    return (organizationId, venueId);
  }
}
