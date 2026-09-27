import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/core/money/decimal_amount.dart';
import 'package:venue_wrangler/features/wine_inventory/domain/movement_rules.dart';

void main() {
  test('a transfer cannot exceed the bottles in that slot', () {
    final available = DecimalAmount.parse('4', scale: 3);
    expect(
      transferError(available: available, requested: DecimalAmount.parse('5', scale: 3)),
      contains('does not have'),
    );
    expect(
      transferError(available: available, requested: DecimalAmount.parse('2', scale: 3)),
      isNull,
    );
    expect(
      transferError(available: available, requested: DecimalAmount.parse('1.5', scale: 3)),
      contains('whole'),
    );
  });

  test('a member locker needs a holder and a bar does not', () {
    expect(serviceLocationError(kind: 'member_locker', holderLabel: ''), contains('member'));
    expect(serviceLocationError(kind: 'service_bar', holderLabel: ''), isNull);
    expect(serviceLocationError(kind: 'cellar', holderLabel: 'Ava'), contains('Choose'));
  });

  test('transfers are ledger rows and do not grant movement inserts', () {
    final sql = File('supabase/migrations/20260927000400_phase4_movements.sql').readAsStringSync();
    expect(sql.contains('function public.transfer_inventory'), isTrue);
    expect(sql.contains('insufficient_quantity'), isTrue);
    expect(sql.contains('source_slot_id'), isTrue);
    expect(sql.contains('transfer_locker'), isTrue);
    expect(sql.contains('grant insert on public.inventory_movements'), isFalse);
    expect(sql.contains('wine.movement.write'), isTrue);
  });
}
