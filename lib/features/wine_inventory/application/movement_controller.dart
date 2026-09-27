import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/application/workspace_controller.dart';
import '../data/supabase_movement_repository.dart';
import '../domain/movement_repository.dart';

class MovementDesk {
  const MovementDesk({
    required this.movable,
    required this.destinations,
    required this.recent,
  });

  final List<MovableLot> movable;
  final List<ServiceLocation> destinations;
  final List<TransferRecord> recent;

  static const empty = MovementDesk(movable: [], destinations: [], recent: []);
}

final movementRepositoryProvider = Provider<MovementRepository>((ref) {
  return SupabaseMovementRepository(Supabase.instance.client);
});

final movementDeskProvider = AsyncNotifierProvider<MovementController, MovementDesk>(
  MovementController.new,
);

class MovementController extends AsyncNotifier<MovementDesk> {
  @override
  Future<MovementDesk> build() async {
    final venueId = ref.watch(workspaceControllerProvider).venueId;
    if (venueId == null) return MovementDesk.empty;
    final repository = ref.read(movementRepositoryProvider);
    final results = await Future.wait([
      repository.movable(venueId),
      repository.destinations(venueId),
      repository.recent(venueId),
    ]);
    return MovementDesk(
      movable: results[0] as List<MovableLot>,
      destinations: results[1] as List<ServiceLocation>,
      recent: results[2] as List<TransferRecord>,
    );
  }

  Future<void> createDestination({
    required String kind,
    required String name,
    required String code,
    String? holderLabel,
  }) async {
    final selection = ref.read(workspaceControllerProvider);
    await ref.read(movementRepositoryProvider).createDestination(
      organizationId: selection.organizationId!,
      venueId: selection.venueId!,
      kind: kind,
      name: name,
      code: code,
      holderLabel: holderLabel,
    );
    ref.invalidateSelf();
  }

  Future<TransferResult> transfer({
    required String lotId,
    required String sourceSlotId,
    required String destinationLocationId,
    required String quantity,
  }) async {
    final selection = ref.read(workspaceControllerProvider);
    final result = await ref.read(movementRepositoryProvider).transfer(
      organizationId: selection.organizationId!,
      venueId: selection.venueId!,
      lotId: lotId,
      sourceSlotId: sourceSlotId,
      destinationLocationId: destinationLocationId,
      quantity: quantity,
    );
    ref.invalidateSelf();
    return result;
  }
}
