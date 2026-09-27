class MovableLot {
  const MovableLot({
    required this.lotId,
    required this.slotId,
    required this.locationCode,
    required this.label,
    required this.quantity,
  });

  final String lotId;
  final String slotId;
  final String locationCode;
  final String label;
  final String quantity;
}

class ServiceLocation {
  const ServiceLocation({
    required this.id,
    required this.kind,
    required this.name,
    required this.code,
    this.holderLabel,
  });

  final String id;
  final String kind;
  final String name;
  final String code;
  final String? holderLabel;
}

class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.reason,
    required this.quantity,
    required this.sourceCode,
    required this.destinationName,
    required this.sourceBefore,
    required this.sourceAfter,
    required this.createdAt,
  });

  final String id;
  final String reason;
  final String quantity;
  final String sourceCode;
  final String destinationName;
  final String sourceBefore;
  final String sourceAfter;
  final DateTime createdAt;
}

class TransferResult {
  const TransferResult({
    required this.movementId,
    required this.sourceBefore,
    required this.sourceAfter,
    required this.destinationBefore,
    required this.destinationAfter,
    required this.reason,
  });

  final String movementId;
  final String sourceBefore;
  final String sourceAfter;
  final String destinationBefore;
  final String destinationAfter;
  final String reason;
}

abstract interface class MovementRepository {
  Future<List<MovableLot>> movable(String venueId);
  Future<List<ServiceLocation>> destinations(String venueId);
  Future<List<TransferRecord>> recent(String venueId);
  Future<void> createDestination({
    required String organizationId,
    required String venueId,
    required String kind,
    required String name,
    required String code,
    String? holderLabel,
  });
  Future<TransferResult> transfer({
    required String organizationId,
    required String venueId,
    required String lotId,
    required String sourceSlotId,
    required String destinationLocationId,
    required String quantity,
  });
}
