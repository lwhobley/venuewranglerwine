import '../../../core/money/decimal_amount.dart';

const serviceLocationKinds = <String>['service_bar', 'event_staging', 'member_locker'];

String? transferError({
  required DecimalAmount available,
  required DecimalAmount requested,
}) {
  final zero = DecimalAmount.zero(scale: 3);
  if (requested.compareTo(zero) <= 0) return 'Enter at least one bottle.';
  if (!requested.toString().endsWith('.000')) return 'Move whole bottles.';
  if (requested.compareTo(available) > 0) return 'That slot does not have that many bottles of this lot.';
  return null;
}

String? serviceLocationError({
  required String kind,
  required String holderLabel,
}) {
  if (!serviceLocationKinds.contains(kind)) return 'Choose a bar, event hold, or member locker.';
  if (kind == 'member_locker' && holderLabel.trim().length < 2) {
    return 'Name the member who holds this locker.';
  }
  return null;
}
