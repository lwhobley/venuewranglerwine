import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/core/money/decimal_amount.dart';
import 'package:venue_wrangler/features/wine_inventory/domain/cellar_rules.dart';

void main() {
  test('slot codes match the cellar address format', () {
    expect(
      slotLocationCode(roomCode: 'cellar-a', unitCode: 'rack-01', row: 5, column: 12),
      'CELLAR-A/RACK-01/SIDE-A/ROW-05/BIN-12',
    );
    expect(slotCount(rows: 5, columns: 6), 30);
  });

  test('csv import rejects duplicates and accepts non-vintage', () {
    const csv = '''
sku,producer,cuvee,wine_type,vintage,bottle_ml,country,region,unit_cost
CLB-003,"North Slope, Cellars",Estate Brut,sparkling,NV,750,United States,Willamette Valley,22.7500
CLB-003,North Slope Cellars,Estate Brut,sparkling,NV,750,United States,Willamette Valley,22.7500
CLB-009,Broken Row,Cuvee,port,2020,750,Portugal,Douro,10
''';
    final preview = parseWineCsv(csv);
    expect(preview.validRows, hasLength(1));
    expect(preview.validRows.single.producer, 'North Slope, Cellars');
    expect(preview.validRows.single.vintage, isNull);
    expect(preview.invalidRows.map((row) => row.error).join(' '), contains('Duplicate'));
    expect(preview.invalidRows.map((row) => row.error).join(' '), contains('wine type'));
  });

  test('put-away cannot exceed staging or slot capacity', () {
    final staged = DecimalAmount.parse('6', scale: 3);
    expect(
      putAwayError(
        staged: staged,
        requested: DecimalAmount.parse('7', scale: 3),
        slotOnHand: DecimalAmount.zero(scale: 3),
        slotCapacity: 12,
      ),
      contains('Staging'),
    );
    expect(
      putAwayError(
        staged: staged,
        requested: DecimalAmount.parse('2', scale: 3),
        slotOnHand: DecimalAmount.parse('11', scale: 3),
        slotCapacity: 12,
      ),
      contains('slot'),
    );
    expect(
      putAwayError(
        staged: staged,
        requested: DecimalAmount.parse('1.5', scale: 3),
        slotOnHand: DecimalAmount.zero(scale: 3),
        slotCapacity: 12,
      ),
      contains('whole'),
    );
  });

  test('cellar migration keeps numeric money and blocks movement edits', () {
    final sql = File('supabase/migrations/20260927000200_phase2_cellar.sql').readAsStringSync();
    const tables = [
      'storage_locations',
      'storage_unit_templates',
      'storage_units',
      'storage_slots',
      'cellar_map_versions',
      'vendors',
      'inventory_items',
      'wine_profiles',
      'inventory_lots',
      'inventory_movements',
      'inventory_balances',
      'receipts',
    ];
    for (final table in tables) {
      expect(sql.contains('alter table public.$table enable row level security'), isTrue, reason: table);
    }
    expect(sql.contains('double precision'), isFalse);
    expect(sql.contains('numeric(14, 4)'), isTrue);
    expect(sql.contains('numeric(14, 3)'), isTrue);
    expect(sql.contains('inventory_movements_immutable'), isTrue);
    expect(sql.contains('grant insert on public.inventory_movements'), isFalse);
    expect(sql.contains('function public.receive_to_staging'), isTrue);
    expect(sql.contains('function public.put_away'), isTrue);
    expect(sql.contains("grant select (id, organization_id, sku, name, status, barcode)"), isTrue);
  });
}
