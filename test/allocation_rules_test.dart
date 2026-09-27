import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/features/wine_inventory/domain/allocation_rules.dart';

void main() {
  test('two lines cannot both claim the same house bottles', () {
    expect(
      projectedShortage(
        required: 6,
        reserved: 0,
        houseAvailable: 6,
        priorUnreservedNeed: 0,
        draft: true,
      ),
      0,
    );
    expect(
      projectedShortage(
        required: 6,
        reserved: 0,
        houseAvailable: 6,
        priorUnreservedNeed: 6,
        draft: true,
      ),
      6,
    );
  });

  test('pickup cannot exceed bottles still reserved', () {
    expect(canPickup(reserved: 4, fulfilled: 1, quantity: 3), isTrue);
    expect(canPickup(reserved: 4, fulfilled: 1, quantity: 4), isFalse);
    expect(houseLeftAfterReserve(house: 10, reserved: 4), 6);
  });

  test('allocation writes are functions and house stock is the only reservable class', () {
    final sql = File('supabase/migrations/20260927000500_phase5_allocations.sql').readAsStringSync();
    expect(sql.contains('function public.reserve_allocation'), isTrue);
    expect(sql.contains("ownership_class = 'house'"), isTrue);
    expect(sql.contains("ownership_class = 'allocated'"), isTrue);
    expect(sql.contains('grant insert on public.allocation_holds'), isFalse);
    expect(sql.contains('alter table public.allocation_lines enable row level security'), isTrue);
    expect(sql.contains('insufficient_reserved'), isTrue);
  });
}
