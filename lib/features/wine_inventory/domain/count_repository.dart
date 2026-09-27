class CountSessionSummary {
  const CountSessionSummary({
    required this.id,
    required this.kind,
    required this.mode,
    required this.status,
    required this.createdAt,
    required this.countedLines,
    required this.openLines,
  });

  final String id;
  final String kind;
  final String mode;
  final String status;
  final DateTime createdAt;
  final int countedLines;
  final int openLines;
}

class CountSheetLine {
  const CountSheetLine({
    required this.lineId,
    required this.locationCode,
    required this.sku,
    required this.label,
    required this.countedQuantity,
    required this.expectedQuantity,
    required this.conflict,
    required this.otherCountedQuantity,
    required this.reason,
    required this.mode,
    required this.status,
  });

  final String lineId;
  final String locationCode;
  final String sku;
  final String label;
  final String? countedQuantity;
  final String? expectedQuantity;
  final bool conflict;
  final String? otherCountedQuantity;
  final String reason;
  final String mode;
  final String status;
}

class CountEntryResult {
  const CountEntryResult({required this.status, required this.lineId});

  final String status;
  final String lineId;

  bool get isConflict => status == 'conflict';
}

abstract interface class CountRepository {
  Future<List<CountSessionSummary>> listSessions(String venueId);
  Future<String> startSession({
    required String organizationId,
    required String venueId,
    required String kind,
    required String mode,
    String? locationId,
  });
  Future<CountEntryResult> recordEntry({
    required String sessionId,
    required String clientEntryId,
    required String locationCode,
    required String sku,
    required String quantity,
    required String reason,
  });
  Future<void> submit(String sessionId);
  Future<int> approve(String sessionId);
  Future<void> reject(String sessionId);
  Future<void> resolveConflict({required String lineId, required String quantity});
  Future<List<CountSheetLine>> sheet(String sessionId);
}
