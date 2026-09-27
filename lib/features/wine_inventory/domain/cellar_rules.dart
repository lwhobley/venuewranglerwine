import '../../../core/money/decimal_amount.dart';

const wineTypes = <String>[
  'red',
  'white',
  'rose',
  'sparkling',
  'champagne',
  'orange',
  'dessert',
  'fortified',
  'sake',
  'non_alcoholic',
];

class WineImportRow {
  const WineImportRow({
    required this.line,
    required this.sku,
    required this.producer,
    required this.cuvee,
    required this.wineType,
    required this.vintage,
    required this.bottleMl,
    required this.country,
    required this.region,
    required this.unitCost,
    required this.error,
  });

  final int line;
  final String sku;
  final String producer;
  final String cuvee;
  final String wineType;
  final int? vintage;
  final int bottleMl;
  final String country;
  final String region;
  final String unitCost;
  final String? error;

  bool get isValid => error == null;

  Map<String, Object?> toJson() {
    return {
      'sku': sku,
      'producer': producer,
      'cuvee': cuvee,
      'wine_type': wineType,
      'vintage': vintage == null ? 'NV' : '$vintage',
      'bottle_ml': '$bottleMl',
      'country': country,
      'region': region,
      'unit_cost': unitCost,
      'format_name': '${bottleMl}ml',
    };
  }
}

class WineImportPreview {
  const WineImportPreview(this.rows);

  final List<WineImportRow> rows;

  List<WineImportRow> get validRows => rows.where((row) => row.isValid).toList();
  List<WineImportRow> get invalidRows => rows.where((row) => !row.isValid).toList();
}

String slotLocationCode({
  required String roomCode,
  required String unitCode,
  required int row,
  required int column,
  String side = 'A',
}) {
  return '${roomCode.toUpperCase()}/${unitCode.toUpperCase()}/SIDE-$side/ROW-${row.toString().padLeft(2, '0')}/BIN-${column.toString().padLeft(2, '0')}';
}

int slotCount({required int rows, required int columns}) => rows * columns;

String? putAwayError({
  required DecimalAmount staged,
  required DecimalAmount requested,
  required DecimalAmount slotOnHand,
  required int slotCapacity,
}) {
  final zero = DecimalAmount.zero(scale: 3);
  if (!requested.isNegative && requested.compareTo(zero) <= 0) {
    return 'Enter at least one bottle.';
  }
  if (!_isWholeBottles(requested)) return 'Receive and put away whole bottles.';
  if (requested.compareTo(staged) > 0) return 'Staging does not have that many bottles.';
  if (slotOnHand.plus(requested).compareTo(DecimalAmount.parse('$slotCapacity', scale: 3)) > 0) {
    return 'That slot cannot hold that many bottles.';
  }
  return null;
}

bool _isWholeBottles(DecimalAmount amount) {
  return amount.toString().endsWith('.000');
}

WineImportPreview parseWineCsv(String raw) {
  final table = _parseCsv(raw.replaceFirst('\uFEFF', ''));
  if (table.isEmpty) {
    return const WineImportPreview([
      WineImportRow(
        line: 1,
        sku: '',
        producer: '',
        cuvee: '',
        wineType: '',
        vintage: null,
        bottleMl: 0,
        country: '',
        region: '',
        unitCost: '',
        error: 'Add a header row and at least one wine.',
      ),
    ]);
  }
  final header = table.first.map((cell) => cell.trim().toLowerCase()).toList();
  final index = {for (var i = 0; i < header.length; i++) header[i]: i};
  const required = ['sku', 'producer', 'cuvee', 'wine_type', 'vintage', 'bottle_ml', 'unit_cost'];
  if (required.any((column) => !index.containsKey(column))) {
    return WineImportPreview([
      WineImportRow(
        line: 1,
        sku: '',
        producer: '',
        cuvee: '',
        wineType: '',
        vintage: null,
        bottleMl: 0,
        country: '',
        region: '',
        unitCost: '',
        error: 'Header must include ${required.join(', ')}.',
      ),
    ]);
  }
  final seen = <String>{};
  final rows = <WineImportRow>[];
  for (var i = 1; i < table.length; i++) {
    final cells = table[i];
    if (cells.every((cell) => cell.trim().isEmpty)) continue;
    String cell(String name) {
      final at = index[name];
      if (at == null || at >= cells.length) return '';
      return cells[at].trim();
    }

    final sku = cell('sku').toUpperCase();
    final producer = cell('producer');
    final cuvee = cell('cuvee');
    final wineType = cell('wine_type').toLowerCase();
    final vintageRaw = cell('vintage').toUpperCase();
    final bottleRaw = cell('bottle_ml');
    final costRaw = cell('unit_cost');
    String? error;
    int? vintage;
    var bottleMl = 0;
    var unitCost = '';
    if (!RegExp(r'^[A-Z0-9][A-Z0-9-]{1,31}$').hasMatch(sku)) {
      error = 'SKU must be 2 to 32 letters, numbers, or hyphens.';
    } else if (seen.contains(sku)) {
      error = 'Duplicate SKU in this file.';
    } else if (producer.length < 2 || cuvee.isEmpty) {
      error = 'Producer and cuvee are required.';
    } else if (!wineTypes.contains(wineType)) {
      error = 'Unknown wine type.';
    } else if (vintageRaw.isNotEmpty && vintageRaw != 'NV') {
      vintage = int.tryParse(vintageRaw);
      if (vintage == null || vintage < 1900 || vintage > 2100) {
        error = 'Vintage must be a year or NV.';
      }
    }
    if (error == null) {
      bottleMl = int.tryParse(bottleRaw) ?? 0;
      if (bottleMl <= 0) error = 'Bottle size must be millilitres.';
    }
    if (error == null) {
      try {
        unitCost = DecimalAmount.parse(costRaw.isEmpty ? '0' : costRaw).toString();
      } on FormatException {
        error = 'Unit cost must be a decimal amount.';
      }
    }
    seen.add(sku);
    rows.add(
      WineImportRow(
        line: i + 1,
        sku: sku,
        producer: producer,
        cuvee: cuvee,
        wineType: wineType,
        vintage: vintage,
        bottleMl: bottleMl,
        country: cell('country'),
        region: cell('region'),
        unitCost: unitCost,
        error: error,
      ),
    );
  }
  if (rows.isEmpty) {
    return const WineImportPreview([
      WineImportRow(
        line: 2,
        sku: '',
        producer: '',
        cuvee: '',
        wineType: '',
        vintage: null,
        bottleMl: 0,
        country: '',
        region: '',
        unitCost: '',
        error: 'No wine rows were found.',
      ),
    ]);
  }
  return WineImportPreview(rows);
}

List<List<String>> _parseCsv(String raw) {
  final rows = <List<String>>[];
  final row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(char);
      }
      continue;
    }
    if (char == '"') {
      quoted = true;
    } else if (char == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (char == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(List.of(row));
      row.clear();
    } else {
      cell.write(char);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(List.of(row));
  }
  return rows.where((line) => line.any((value) => value.trim().isNotEmpty)).toList();
}
