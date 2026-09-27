class ServiceListItem {
  const ServiceListItem({
    required this.listId,
    required this.listName,
    required this.published,
    required this.listItemId,
    required this.itemId,
    required this.sku,
    required this.label,
    required this.pourMl,
    required this.manual86,
    required this.houseBottles,
    required this.openRemainingMl,
    required this.available,
    required this.unavailableReason,
  });

  final String listId;
  final String listName;
  final bool published;
  final String listItemId;
  final String itemId;
  final String sku;
  final String label;
  final int? pourMl;
  final bool manual86;
  final String houseBottles;
  final int openRemainingMl;
  final bool available;
  final String? unavailableReason;
}

class OpenBottleRecord {
  const OpenBottleRecord({
    required this.id,
    required this.itemId,
    required this.remainingMl,
    required this.openedMl,
  });

  final String id;
  final String itemId;
  final int remainingMl;
  final int openedMl;
}

abstract interface class ServiceRepository {
  Future<List<ServiceListItem>> board(String venueId);
  Future<List<OpenBottleRecord>> openBottles(String venueId);
  Future<String> createList({
    required String organizationId,
    required String venueId,
    required String name,
    required String kind,
    required int threshold,
  });
  Future<void> addItem({
    required String listId,
    required String itemId,
    int? pourMl,
  });
  Future<void> publish({required String listId, required bool published});
  Future<void> set86({required String listItemId, required bool eightySixed});
  Future<void> openBottle({required String venueId, required String itemId});
  Future<int> pour({
    required String openBottleId,
    required int pourMl,
    required String reason,
  });
}
