import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/application/workspace_controller.dart';
import '../data/supabase_service_repository.dart';
import '../domain/service_repository.dart';

class ServiceDesk {
  const ServiceDesk({required this.board, required this.openBottles});

  final List<ServiceListItem> board;
  final List<OpenBottleRecord> openBottles;

  static const empty = ServiceDesk(board: [], openBottles: []);
}

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return SupabaseServiceRepository(Supabase.instance.client);
});

final serviceDeskProvider = AsyncNotifierProvider<ServiceController, ServiceDesk>(ServiceController.new);

class ServiceController extends AsyncNotifier<ServiceDesk> {
  @override
  Future<ServiceDesk> build() async {
    final venueId = ref.watch(workspaceControllerProvider).venueId;
    if (venueId == null) return ServiceDesk.empty;
    final repository = ref.read(serviceRepositoryProvider);
    final board = await repository.board(venueId);
    final openBottles = await repository.openBottles(venueId);
    return ServiceDesk(board: board, openBottles: openBottles);
  }

  Future<String> createList({required String name, required String kind, required int threshold}) async {
    final selection = ref.read(workspaceControllerProvider);
    final id = await ref.read(serviceRepositoryProvider).createList(
      organizationId: selection.organizationId!,
      venueId: selection.venueId!,
      name: name,
      kind: kind,
      threshold: threshold,
    );
    ref.invalidateSelf();
    return id;
  }

  Future<void> addItem({required String listId, required String itemId, int? pourMl}) async {
    await ref.read(serviceRepositoryProvider).addItem(listId: listId, itemId: itemId, pourMl: pourMl);
    ref.invalidateSelf();
  }

  Future<void> publish({required String listId, required bool published}) async {
    await ref.read(serviceRepositoryProvider).publish(listId: listId, published: published);
    ref.invalidateSelf();
  }

  Future<void> set86({required String listItemId, required bool eightySixed}) async {
    await ref.read(serviceRepositoryProvider).set86(listItemId: listItemId, eightySixed: eightySixed);
    ref.invalidateSelf();
  }

  Future<void> openBottle(String itemId) async {
    final venueId = ref.read(workspaceControllerProvider).venueId!;
    await ref.read(serviceRepositoryProvider).openBottle(venueId: venueId, itemId: itemId);
    ref.invalidateSelf();
  }

  Future<int> pour({required String openBottleId, required int pourMl, required String reason}) async {
    final left = await ref.read(serviceRepositoryProvider).pour(
      openBottleId: openBottleId,
      pourMl: pourMl,
      reason: reason,
    );
    ref.invalidateSelf();
    return left;
  }
}
