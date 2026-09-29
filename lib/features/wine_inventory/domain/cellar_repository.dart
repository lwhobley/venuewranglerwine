import 'cellar_rules.dart';

class CellarRoom {
  const CellarRoom({
    required this.id,
    required this.name,
    required this.code,
    required this.kind,
    this.parentId,
  });

  final String id;
  final String name;
  final String code;
  final String kind;
  final String? parentId;
}

class RackTemplate {
  const RackTemplate({
    required this.key,
    required this.label,
    required this.rows,
    required this.columns,
    required this.slotCapacity,
  });

  final String key;
  final String label;
  final int rows;
  final int columns;
  final int slotCapacity;
}

class StorageUnitRecord {
  const StorageUnitRecord({
    required this.id,
    required this.locationId,
    required this.name,
    required this.code,
    required this.templateKey,
  });

  final String id;
  final String locationId;
  final String name;
  final String code;
  final String templateKey;
}

class StorageSlotRecord {
  const StorageSlotRecord({
    required this.id,
    required this.unitId,
    required this.locationCode,
    required this.capacityBottles,
    required this.onHand,
  });

  final String id;
  final String unitId;
  final String locationCode;
  final int capacityBottles;
  final String onHand;
}

class WineRecord {
  const WineRecord({
    required this.itemId,
    required this.sku,
    required this.producer,
    required this.cuvee,
    required this.wineType,
    required this.bottleMl,
    this.vintage,
    this.catalogName,
  });

  final String itemId;
  final String sku;
  final String producer;
  final String cuvee;
  final String wineType;
  final int bottleMl;
  final int? vintage;
  final String? catalogName;

  String get label => catalogName ?? (vintage == null ? '$producer $cuvee NV' : '$producer $cuvee $vintage');
}

class VendorRecord {
  const VendorRecord({required this.id, required this.name});

  final String id;
  final String name;
}

class StagedLot {
  const StagedLot({
    required this.lotId,
    required this.itemId,
    required this.quantity,
    required this.label,
  });

  final String lotId;
  final String itemId;
  final String quantity;
  final String label;
}

class CellarSnapshot {
  const CellarSnapshot({
    required this.rooms,
    required this.templates,
    required this.units,
    required this.slots,
    required this.wines,
    required this.vendors,
    required this.staged,
    this.stagingId,
  });

  final List<CellarRoom> rooms;
  final List<RackTemplate> templates;
  final List<StorageUnitRecord> units;
  final List<StorageSlotRecord> slots;
  final List<WineRecord> wines;
  final List<VendorRecord> vendors;
  final List<StagedLot> staged;
  final String? stagingId;

  static const empty = CellarSnapshot(
    rooms: [],
    templates: [],
    units: [],
    slots: [],
    wines: [],
    vendors: [],
    staged: [],
  );
}

class WineImportResult {
  const WineImportResult({
    required this.imported,
    required this.updated,
    required this.errors,
  });

  final int imported;
  final int updated;
  final List<String> errors;
}

abstract interface class CellarRepository {
  Future<CellarSnapshot> load({required String organizationId, required String venueId});
  Future<void> createRoom({
    required String organizationId,
    required String venueId,
    required String name,
    required String code,
  });
  Future<void> placeUnit({
    required String organizationId,
    required String venueId,
    required String locationId,
    required String templateKey,
    required String name,
    required String code,
  });
  Future<void> createVendor({
    required String organizationId,
    required String name,
    String? email,
  });
  Future<WineImportResult> importWines({
    required String organizationId,
    required List<WineImportRow> rows,
  });
  Future<void> receive({
    required String organizationId,
    required String venueId,
    required String vendorId,
    required String itemId,
    required String quantity,
    required String unitCost,
  });
  Future<void> putAway({
    required String organizationId,
    required String venueId,
    required String lotId,
    required String slotId,
    required String quantity,
  });
}
