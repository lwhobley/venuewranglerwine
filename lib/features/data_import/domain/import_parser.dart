import 'dart:convert';

import '../../../core/money/decimal_amount.dart';
import '../../../core/permissions/app_role.dart';
import 'import_schema.dart';

class ImportTable {
  const ImportTable(this.name, this.rows);
  final String name;
  final List<List<String>> rows;

  int suggestedHeader(ImportSchema schema) {
    var best = 0;
    var score = 0;
    for (var i = 0; i < rows.length && i < 20; i++) {
      final next = suggestImportMapping(schema, rows[i]).length;
      if (next > score) {
        best = i;
        score = next;
      }
    }
    return best;
  }
}

class ImportPreviewRow {
  const ImportPreviewRow(this.line, this.values, this.errors);
  final int line;
  final Map<String, String> values;
  final List<String> errors;
  bool get isValid => errors.isEmpty;
}

ImportTable parseImportText(String raw, {String name = 'Pasted data'}) {
  final text = raw
      .replaceFirst('\uFEFF', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (text.isEmpty) throw const FormatException('Add some data first.');
  if (text.length > 2000000) {
    throw const FormatException(
      'Use a file smaller than 2 MB of extracted text.',
    );
  }
  // A pasted form or OCR form can be one or more key: value blocks.
  final blocks = text.split(RegExp(r'\n\s*\n'));
  final forms = <Map<String, String>>[];
  for (final block in blocks) {
    final values = <String, String>{};
    final lines = block.split('\n');
    if (!lines.every(
      (line) => RegExp(r'^[\w ()/-]{2,40}:\s*').hasMatch(line),
    )) {
      forms.clear();
      break;
    }
    for (final line in lines) {
      final at = line.indexOf(':');
      values[line.substring(0, at).trim()] = line.substring(at + 1).trim();
    }
    forms.add(values);
  }
  if (forms.isNotEmpty) {
    final headers = forms.expand((row) => row.keys).toSet().toList();
    return ImportTable(name, [
      headers,
      for (final row in forms) [for (final key in headers) row[key] ?? ''],
    ]);
  }
  final first = text.split('\n').first;
  final delimiter = first.contains('\t')
      ? '\t'
      : first.contains(',')
      ? ','
      : first.contains(';')
      ? ';'
      : first.contains('|')
      ? '|'
      : null;
  if (delimiter == null) {
    return ImportTable(
      name,
      text
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.trim().split(RegExp(r'\s{2,}')))
          .toList(),
    );
  }
  final rows = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  var closed = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"' && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (char == '"') {
        quoted = false;
        closed = true;
      } else {
        cell.write(char);
      }
    } else if (char == delimiter || char == '\n') {
      row.add(cell.toString().trim());
      cell = StringBuffer();
      closed = false;
      if (char == '\n') {
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = [];
      }
    } else if (char == '"' && cell.isEmpty && !closed) {
      quoted = true;
    } else if (closed && char.trim().isNotEmpty) {
      throw const FormatException('Unexpected text after a quoted cell.');
    } else if (!closed) {
      cell.write(char);
    }
  }
  if (quoted) {
    throw const FormatException('A quoted cell is missing its closing quote.');
  }
  row.add(cell.toString().trim());
  if (row.any((value) => value.isNotEmpty)) rows.add(row);
  return ImportTable(name, rows);
}

List<ImportPreviewRow> previewImport(
  ImportSchema schema,
  ImportTable table,
  int headerIndex,
  Map<String, int> mapping,
) {
  if (table.rows.length - headerIndex - 1 > 500) {
    throw const FormatException('Import up to 500 rows at a time.');
  }
  final result = <ImportPreviewRow>[];
  final seen = <String>{};
  final width = table.rows[headerIndex].length;
  final namedHeaders = table.rows[headerIndex]
      .map(normalizeImportHeader)
      .where((name) => name.isNotEmpty)
      .toList();
  if (namedHeaders.toSet().length != namedHeaders.length) {
    throw const FormatException(
      'The header has duplicate column names. Rename them before importing.',
    );
  }
  for (var i = headerIndex + 1; i < table.rows.length; i++) {
    final cells = table.rows[i];
    if (cells.every((cell) => cell.trim().isEmpty)) continue;
    if (cells.map(normalizeImportHeader).join('|') ==
        table.rows[headerIndex].map(normalizeImportHeader).join('|')) {
      continue;
    }
    final values = <String, String>{};
    final errors = <String>[];
    if (cells.length > width) {
      errors.add(
        'This row has more cells than the header. Fix its delimiters before importing.',
      );
    }
    for (final field in schema.fields) {
      final index = mapping[field.key];
      var value = (index != null && index < cells.length ? cells[index] : '')
          .trim();
      if (value.isEmpty) value = field.defaultValue;
      if (value.isEmpty) {
        if (field.required) errors.add('${field.label} is required.');
        values[field.key] = value;
        continue;
      }
      if (field.min != null &&
          field.type == ImportValueType.text &&
          value.length < field.min!) {
        errors.add('${field.label} is too short.');
      }
      if (field.max != null &&
          (field.type == ImportValueType.text ||
              field.type == ImportValueType.code) &&
          value.length > field.max!) {
        errors.add('${field.label} is too long.');
      }
      switch (field.type) {
        case ImportValueType.code:
          value = value.toUpperCase();
          if (!RegExp(r'^[A-Z0-9]+(?:-[A-Z0-9]+)*$').hasMatch(value) ||
              (field.min != null && value.length < field.min!)) {
            errors.add(
              '${field.label} must use letters, numbers, and hyphens.',
            );
          }
        case ImportValueType.integer:
          final number = int.tryParse(value);
          if (number == null ||
              (field.min != null && number < field.min!) ||
              (field.max != null && number > field.max!)) {
            errors.add(
              '${field.label} is outside its allowed whole-number range.',
            );
          } else {
            value = number.toString();
          }
        case ImportValueType.decimal:
          try {
            final amount = DecimalAmount.parse(value, scale: 4);
            if (amount.isNegative ||
                amount > DecimalAmount.parse('9999999999.9999')) {
              throw const FormatException('Cost out of range');
            }
            value = amount.toString();
          } on FormatException {
            errors.add(
              '${field.label} must be 0–9999999999.9999 with at most four decimal places.',
            );
          }
        case ImportValueType.boolean:
          final lower = value.toLowerCase();
          if (['true', 'yes', '1'].contains(lower)) {
            value = 'true';
          } else if (['false', 'no', '0'].contains(lower)) {
            value = 'false';
          } else {
            errors.add('${field.label} must be yes/no or true/false.');
          }
        case ImportValueType.timestamp:
          final parsed = DateTime.tryParse(value);
          if (parsed == null || !_validImportTimestamp(value)) {
            errors.add(
              '${field.label} needs a valid ISO date/time with Z or a UTC offset.',
            );
          } else {
            value = parsed.toUtc().toIso8601String();
          }
        case ImportValueType.email:
          value = value.toLowerCase();
          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
            errors.add('${field.label} is not a valid email.');
          }
        case ImportValueType.text:
          break;
      }
      if (field.choices.isNotEmpty) {
        value = normalizeImportHeader(value);
        if (!field.choices.contains(value)) {
          errors.add('${field.label}: choose ${field.choices.join(', ')}.');
        }
      }
      values[field.key] = value;
    }
    if (schema.key == 'wines' && values['vintage']!.toUpperCase() != 'NV') {
      final year = int.tryParse(values['vintage']!);
      if (year == null || year < 1900 || year > 2100) {
        errors.add('Vintage must be 1900–2100 or NV.');
      }
    }
    if (schema.key == 'shifts') {
      if (AppRole.byKey(values['role_key']!) == null) {
        errors.add('Choose a known role key.');
      }
      final start = DateTime.tryParse(values['starts_at']!);
      final end = DateTime.tryParse(values['ends_at']!);
      if (start != null && end != null && !end.isAfter(start)) {
        errors.add('Shift end must be after its start.');
      }
    }
    if (schema.key == 'locations' && values['code'] == values['parent_code']) {
      errors.add('A location cannot be its own parent.');
    }
    if (schema.key == 'list_items' &&
        values['list_kind'] == 'glass' &&
        values['pour_ml']!.isEmpty) {
      errors.add('Glass lists require a pour size.');
    }
    final key = jsonEncode(
      schema.keyFields.map((field) => values[field]!.toLowerCase()).toList(),
    );
    if (!seen.add(key)) errors.add('Duplicate source key in this import.');
    result.add(ImportPreviewRow(i + 1, values, errors));
  }
  return result;
}

bool _validImportTimestamp(String value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,6})?)?(?:[Zz]|([+-])(\d{2}):?(\d{2}))$',
  ).firstMatch(value);
  if (match == null) return false;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  return date.year == year &&
      date.month == month &&
      date.day == day &&
      int.parse(match[4]!) < 24 &&
      int.parse(match[5]!) < 60 &&
      int.parse(match[6] ?? '0') < 60 &&
      int.parse(match[8] ?? '0') <= 14 &&
      int.parse(match[9] ?? '0') < 60 &&
      (match[8] != '14' || match[9] == '00');
}

List<ImportPreviewRow> orderLocationRows(List<ImportPreviewRow> rows) {
  final byCode = {for (final row in rows) row.values['code']!: row};
  final done = <String>{};
  final visiting = <String>{};
  final ordered = <ImportPreviewRow>[];
  void visit(ImportPreviewRow row) {
    final code = row.values['code']!;
    if (done.contains(code)) return;
    if (!visiting.add(code)) {
      throw const FormatException('The location parent codes form a cycle.');
    }
    final parent = byCode[row.values['parent_code']];
    if (parent != null) visit(parent);
    visiting.remove(code);
    done.add(code);
    ordered.add(row);
  }

  for (final row in rows) {
    visit(row);
  }
  return ordered;
}

String importTableText(List<List<String>> rows) => rows
    .map(
      (row) => row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','),
    )
    .join('\n');

class PositionedImportText {
  const PositionedImportText(
    this.text,
    this.left,
    this.top,
    this.right,
    this.height,
  );
  final String text;
  final double left, top, right, height;
}

String positionedImportText(List<PositionedImportText> atoms) {
  final sorted = atoms.where((atom) => atom.text.trim().isNotEmpty).toList()
    ..sort((a, b) => a.top.compareTo(b.top));
  final lines = <List<PositionedImportText>>[];
  for (final atom in sorted) {
    final at = lines.indexWhere(
      (line) =>
          (line.first.top - atom.top).abs() <
          (line.first.height + atom.height) / 3,
    );
    if (at < 0) {
      lines.add([atom]);
    } else {
      lines[at].add(atom);
    }
  }
  return lines
      .map((line) {
        line.sort((a, b) => a.left.compareTo(b.left));
        final text = StringBuffer();
        PositionedImportText? previous;
        for (final atom in line) {
          if (previous != null) {
            text.write(
              atom.left - previous.right > atom.height * 1.2 ? '\t' : ' ',
            );
          }
          text.write(atom.text.trim());
          previous = atom;
        }
        return text.toString();
      })
      .join('\n');
}
