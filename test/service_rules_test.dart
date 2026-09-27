import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/features/wine_inventory/domain/service_rules.dart';

void main() {
  test('a glass stays available from an open bottle after house stock is gone', () {
    expect(
      listItemAvailable(
        published: true,
        manual86: false,
        houseBottles: 0,
        threshold: 1,
        openRemainingMl: 150,
        pourMl: 150,
      ),
      isTrue,
    );
    expect(
      listItemAvailable(
        published: true,
        manual86: false,
        houseBottles: 0,
        threshold: 1,
        openRemainingMl: 100,
        pourMl: 150,
      ),
      isFalse,
    );
    expect(
      unavailableReason(
        published: true,
        manual86: true,
        houseBottles: 4,
        threshold: 1,
        openRemainingMl: 750,
        pourMl: 150,
      ),
      'manual_86',
    );
  });

  test('a pour cannot exceed the open bottle', () {
    expect(remainingAfterPour(remainingMl: 750, pourMl: 150), 600);
    expect(remainingAfterPour(remainingMl: 100, pourMl: 150), isNull);
  });

  test('opening a bottle is a house-stock movement, not an allocated one', () {
    final sql = File('supabase/migrations/20260927000600_phase6_service.sql').readAsStringSync();
    expect(sql.contains("ownership_class = 'house'"), isTrue);
    expect(sql.contains('function public.record_pour'), isTrue);
    expect(sql.contains('insufficient_pour'), isTrue);
    expect(sql.contains('grant insert on public.service_depletions'), isFalse);
    expect(sql.contains('alter table public.open_bottles enable row level security'), isTrue);
  });
}
