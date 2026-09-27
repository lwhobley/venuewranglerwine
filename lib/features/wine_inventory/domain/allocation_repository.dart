class ClubMember {
  const ClubMember({required this.id, required this.name, required this.tier});

  final String id;
  final String name;
  final String tier;
}

class AllocationCampaign {
  const AllocationCampaign({
    required this.id,
    required this.name,
    required this.releaseOn,
    required this.status,
    required this.lineCount,
  });

  final String id;
  final String name;
  final String releaseOn;
  final String status;
  final int lineCount;
}

class AllocationReadinessLine {
  const AllocationReadinessLine({
    required this.lineId,
    required this.memberName,
    required this.sku,
    required this.label,
    required this.required,
    required this.reserved,
    required this.fulfilled,
    required this.houseAvailable,
    required this.shortage,
    required this.status,
  });

  final String lineId;
  final String memberName;
  final String sku;
  final String label;
  final String required;
  final String reserved;
  final String fulfilled;
  final String houseAvailable;
  final String shortage;
  final String status;
}

abstract interface class AllocationRepository {
  Future<List<ClubMember>> members(String organizationId);
  Future<List<AllocationCampaign>> campaigns(String venueId);
  Future<void> createMember({
    required String organizationId,
    required String name,
    required String tier,
  });
  Future<String> createCampaign({
    required String organizationId,
    required String venueId,
    required String name,
    required String releaseOn,
  });
  Future<void> addLine({
    required String campaignId,
    required String memberId,
    required String itemId,
    required String quantity,
  });
  Future<int> reserve(String campaignId);
  Future<void> pickup({required String lineId, required String quantity});
  Future<List<AllocationReadinessLine>> readiness(String campaignId);
}
