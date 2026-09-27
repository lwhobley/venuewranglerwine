import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venue_wrangler/core/money/decimal_amount.dart';
import 'package:venue_wrangler/features/wine_inventory/data/count_draft_store.dart';
import 'package:venue_wrangler/features/wine_inventory/domain/count_rules.dart';

void main() {
  test('an approved variance adjusts current stock and does not replace it', () {
    final current = DecimalAmount.parse('8', scale: 3);
    final expected = DecimalAmount.parse('6', scale: 3);
    final counted = DecimalAmount.parse('4', scale: 3);
    expect(
      CountVariance.apply(current: current, expected: expected, counted: counted).toString(),
      '6.000',
    );
    expect(
      CountVariance.wouldGoNegative(
        current: DecimalAmount.parse('1', scale: 3),
        expected: DecimalAmount.parse('6', scale: 3),
        counted: DecimalAmount.parse('0', scale: 3),
      ),
      isTrue,
    );
  });

  test('blind counts hide expected quantity from the counter', () {
    expect(
      visibleExpected(blind: true, canReview: false, expected: '6'),
      isNull,
    );
    expect(
      visibleExpected(blind: true, canReview: true, expected: '6'),
      '6',
    );
  });

  test('a location label payload is the same code a QR would carry', () {
    expect(parseLocationScan('vw:loc:CELLAR-A/RACK-01/SIDE-A/ROW-05/BIN-12'),
      'CELLAR-A/RACK-01/SIDE-A/ROW-05/BIN-12',
    );
    expect(parseLocationScan('not a code'), isNull);
  });

  test('count drafts stay on the device until sync', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = CountDraftStore(preferences);
    await store.save(
      CountDraft(
        clientEntryId: 'entry-1',
        sessionId: 'session-1',
        locationCode: 'CELLAR-A/RACK-01/SIDE-A/ROW-01/BIN-01',
        sku: 'CLB-001',
        quantity: '4',
        reason: 'short',
        syncStatus: 'pending',
      ),
    );
    final reloaded = CountDraftStore(preferences);
    expect(reloaded.draftsFor('session-1').single.quantity, '4');
    expect(reloaded.lastSync(), isNull);
  });

  test('count approval is a movement, and lines are not client-writable', () {
    final sql = File('supabase/migrations/20260927000300_phase3_counts.sql').readAsStringSync();
    expect(sql.contains('count_adjustment'), isTrue);
    expect(sql.contains('function public.approve_count_session'), isTrue);
    expect(sql.contains('wine.count.approve'), isTrue);
    expect(sql.contains('grant insert on public.inventory_count_lines'), isFalse);
    expect(sql.contains('alter table public.inventory_count_lines enable row level security'), isTrue);
    expect(sql.contains('v_show_expected'), isTrue);
  });
}
