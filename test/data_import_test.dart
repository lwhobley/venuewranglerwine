import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/features/data_import/data/document_extractor.dart';
import 'package:venue_wrangler/features/data_import/domain/import_parser.dart';
import 'package:venue_wrangler/features/data_import/domain/import_schema.dart';

void main() {
  ImportSchema schema(String key) => importSchemas.firstWhere((s) => s.key == key);
  List<ImportPreviewRow> preview(String key, String text) {
    final table = parseImportText(text);
    final type = schema(key);
    return previewImport(type, table, 0, suggestImportMapping(type, table.rows.first));
  }

  test('CSV preserves escaped quotes, multiline values, empty cells and BOM', () {
    final table = parseImportText('\uFEFFsku,name,barcode\r\nAA,"A ""quoted""\nname",\r\nBB,Bottle,0123');
    expect(table.rows[1], ['AA', 'A "quoted"\nname', '']);
    expect(table.rows[2][2], '0123');
    expect(parseImportText(importTableText(table.rows)).rows, table.rows);
  });

  test('malformed CSV and duplicate headers cannot be imported', () {
    expect(() => parseImportText('sku,name\nAA,"open'), throwsFormatException);
    expect(() => parseImportText('sku,name\nAA,"closed"garbage'), throwsFormatException);
    expect(() => preview('inventory', 'sku,name,Name\nAA,Item,Other'), throwsFormatException);
    expect(preview('inventory', 'sku,name\nAA,Item,Unexpected').single.isValid, false);
  });

  test('pasted forms map aliases, preserve optional columns and apply defaults', () {
    final rows = preview('inventory', 'Product code: aa\nName: Napkins\nCost: 1.25\n\nProduct code: bb\nName: Cups');
    expect(rows.every((r) => r.isValid), true);
    expect(rows.first.values['sku'], 'AA');
    expect(rows.first.values['unit_cost'], '1.2500');
    expect(rows.last.values['unit_cost'], '0.0000');
  });

  test('invalid money, missing fields, duplicate keys and row limits are rejected', () {
    for (final cost in ['-1', '1.12345', '10000000000', 'NaN']) {
      expect(preview('inventory', 'sku,name,cost\nAA,Item,$cost').single.isValid, false);
    }
    expect(preview('inventory', 'sku,name\nAA,').single.isValid, false);
    expect(preview('inventory', 'sku,name\naa,Item\nAA,Item').last.isValid, false);
    final text = 'sku,name\n${List.generate(501, (i) => 'SKU-$i,Item').join('\n')}';
    expect(() => preview('inventory', text), throwsFormatException);
  });

  test('timestamps reject missing offsets, calendar overflow and reversed shifts', () {
    for (final date in ['2026-09-27T12:00:00', '2026-02-30T12:00:00Z', '2026-09-27T25:00:00Z', '2026-09-27T12:00:00+14:30']) {
      expect(preview('events', 'id,name,guests,start\ne1,Party,20,$date').single.isValid, false);
    }
    expect(preview('events', 'id,name,guests,start\ne1,Party,20,2026-09-27T12:00:00-05:00').single.values['starts_at'], '2026-09-27T17:00:00.000Z');
    expect(preview('shifts', 'id,role,start,end\ns1,host,2026-09-27T13:00:00Z,2026-09-27T12:00:00Z').single.isValid, false);
  });

  test('location parents are ordered and cycles are blocked', () {
    final rows = preview('locations', 'code,name,type,parent\nROOM,Cellar,room,OUT\nOUT,Outlet,outlet,CON\nCON,North,concourse,');
    expect(rows.every((r) => r.isValid), true);
    expect(orderLocationRows(rows).map((r) => r.values['code']), ['CON', 'OUT', 'ROOM']);
    final cyclic = preview('locations', 'code,name,type,parent\nAA,First,zone,BB\nBB,Second,zone,AA');
    expect(() => orderLocationRows(cyclic), throwsFormatException);
  });

  test('positioned OCR words retain multiword names and column gaps', () {
    final text = positionedImportText([
      const PositionedImportText('AA', 0, 30, 20, 10),
      const PositionedImportText('sku', 0, 0, 20, 10),
      const PositionedImportText('name', 100, 0, 130, 10),
      const PositionedImportText('Paper', 100, 30, 130, 10),
      const PositionedImportText('cups', 134, 30, 160, 10),
    ]);
    expect(parseImportText(text).rows, [['sku', 'name'], ['AA', 'Paper cups']]);
  });

  test('XLSX extracts each worksheet with numeric values and empty cells', () {
    final workbook = Excel.createExcel();
    workbook['Catalog'].appendRow([TextCellValue('sku'), TextCellValue('name'), TextCellValue('cost')]);
    workbook['Catalog'].appendRow([TextCellValue('AA'), TextCellValue('Item'), DoubleCellValue(2.5)]);
    workbook['Locations'].appendRow([TextCellValue('code'), TextCellValue('parent'), TextCellValue('name')]);
    workbook['Locations'].appendRow([TextCellValue('CON'), null, TextCellValue('North')]);
    final tables = extractImportSpreadsheet(Uint8List.fromList(workbook.encode()!));
    expect(tables.map((t) => t.name), ['Catalog', 'Locations']);
    expect(tables.last.rows.last, ['CON', '', 'North']);
    expect(tables.first.rows.last.last, '2.5');
  });

  test('XLSX formulas require reviewed values', () {
    final workbook = Excel.createExcel();
    workbook['Data'].appendRow([FormulaCellValue('1+1')]);
    expect(() => extractImportSpreadsheet(Uint8List.fromList(workbook.encode()!)), throwsFormatException);
  });
}
