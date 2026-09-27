import '../../../core/money/decimal_amount.dart';

const countKinds = <String>[
  'full',
  'partial',
  'cycle',
  'spot',
  'opening',
  'closing',
  'event_prep',
  'audit',
];

const countModes = <String>['blind', 'expected'];

class CountVariance {
  const CountVariance._();

  static DecimalAmount delta({
    required DecimalAmount expected,
    required DecimalAmount counted,
  }) {
    return counted.minus(expected);
  }

  static DecimalAmount apply({
    required DecimalAmount current,
    required DecimalAmount expected,
    required DecimalAmount counted,
  }) {
    return current.plus(delta(expected: expected, counted: counted));
  }

  static bool wouldGoNegative({
    required DecimalAmount current,
    required DecimalAmount expected,
    required DecimalAmount counted,
  }) {
    return apply(current: current, expected: expected, counted: counted).isNegative;
  }
}

String? visibleExpected({
  required bool blind,
  required bool canReview,
  required String? expected,
}) {
  if (!blind || canReview) return expected;
  return null;
}

String? lotSelectionError({required int lotCount, required String? lotId}) {
  if (lotCount > 1 && (lotId == null || lotId.isEmpty)) {
    return 'Choose the lot before saving this count.';
  }
  return null;
}

String? parseLocationScan(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (lower.startsWith('vw:loc:')) {
    text = text.substring(7).trim();
  }
  text = text.toUpperCase();
  if (!RegExp(r'^[A-Z0-9][A-Z0-9/_-]{2,80}$').hasMatch(text)) return null;
  return text;
}

class CountDraft {
  const CountDraft({
    required this.clientEntryId,
    required this.sessionId,
    required this.locationCode,
    required this.sku,
    this.lotId,
    required this.quantity,
    required this.reason,
    required this.syncStatus,
    this.message,
  });

  final String clientEntryId;
  final String sessionId;
  final String locationCode;
  final String sku;
  final String? lotId;
  final String quantity;
  final String reason;
  final String syncStatus;
  final String? message;

  CountDraft copyWith({String? syncStatus, String? message}) {
    return CountDraft(
      clientEntryId: clientEntryId,
      sessionId: sessionId,
      locationCode: locationCode,
      sku: sku,
      lotId: lotId,
      quantity: quantity,
      reason: reason,
      syncStatus: syncStatus ?? this.syncStatus,
      message: message,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'clientEntryId': clientEntryId,
      'sessionId': sessionId,
      'locationCode': locationCode,
      'sku': sku,
      'lotId': lotId,
      'quantity': quantity,
      'reason': reason,
      'syncStatus': syncStatus,
      'message': message,
    };
  }

  factory CountDraft.fromJson(Map<String, dynamic> json) {
    return CountDraft(
      clientEntryId: json['clientEntryId'] as String,
      sessionId: json['sessionId'] as String,
      locationCode: json['locationCode'] as String,
      sku: json['sku'] as String? ?? '',
      lotId: json['lotId'] as String?,
      quantity: json['quantity'] as String,
      reason: json['reason'] as String? ?? '',
      syncStatus: json['syncStatus'] as String? ?? 'pending',
      message: json['message'] as String?,
    );
  }
}
