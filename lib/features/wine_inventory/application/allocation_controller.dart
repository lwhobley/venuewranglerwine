import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/application/workspace_controller.dart';
import '../data/supabase_allocation_repository.dart';
import '../domain/allocation_repository.dart';

class AllocationDesk {
  const AllocationDesk({
    required this.members,
    required this.campaigns,
  });

  final List<ClubMember> members;
  final List<AllocationCampaign> campaigns;

  static const empty = AllocationDesk(members: [], campaigns: []);
}

final allocationRepositoryProvider = Provider<AllocationRepository>((ref) {
  return SupabaseAllocationRepository(Supabase.instance.client);
});

final allocationDeskProvider = AsyncNotifierProvider<AllocationController, AllocationDesk>(
  AllocationController.new,
);

final allocationReadinessProvider =
    FutureProvider.family<List<AllocationReadinessLine>, String>((ref, campaignId) {
  return ref.watch(allocationRepositoryProvider).readiness(campaignId);
});

class AllocationController extends AsyncNotifier<AllocationDesk> {
  @override
  Future<AllocationDesk> build() async {
    final selection = ref.watch(workspaceControllerProvider);
    if (selection.organizationId == null || selection.venueId == null) {
      return AllocationDesk.empty;
    }
    final repository = ref.read(allocationRepositoryProvider);
    final members = await repository.members(selection.organizationId!);
    final campaigns = await repository.campaigns(selection.venueId!);
    return AllocationDesk(members: members, campaigns: campaigns);
  }

  Future<void> createMember({required String name, required String tier}) async {
    final orgId = ref.read(workspaceControllerProvider).organizationId!;
    await ref.read(allocationRepositoryProvider).createMember(
      organizationId: orgId,
      name: name,
      tier: tier,
    );
    ref.invalidateSelf();
  }

  Future<String> createCampaign({required String name, required String releaseOn}) async {
    final selection = ref.read(workspaceControllerProvider);
    final id = await ref.read(allocationRepositoryProvider).createCampaign(
      organizationId: selection.organizationId!,
      venueId: selection.venueId!,
      name: name,
      releaseOn: releaseOn,
    );
    ref.invalidateSelf();
    return id;
  }

  Future<void> addLine({
    required String campaignId,
    required String memberId,
    required String itemId,
    required String quantity,
  }) async {
    await ref.read(allocationRepositoryProvider).addLine(
      campaignId: campaignId,
      memberId: memberId,
      itemId: itemId,
      quantity: quantity,
    );
    ref.invalidate(allocationReadinessProvider(campaignId));
    ref.invalidateSelf();
  }

  Future<int> reserve(String campaignId) async {
    final holds = await ref.read(allocationRepositoryProvider).reserve(campaignId);
    ref.invalidate(allocationReadinessProvider(campaignId));
    ref.invalidateSelf();
    return holds;
  }

  Future<void> pickup({required String campaignId, required String lineId, required String quantity}) async {
    await ref.read(allocationRepositoryProvider).pickup(lineId: lineId, quantity: quantity);
    ref.invalidate(allocationReadinessProvider(campaignId));
  }
}
