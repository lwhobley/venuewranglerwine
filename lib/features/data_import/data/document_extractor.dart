import 'dart:convert';
import 'dart:ui' as ui;

import 'package:excel_community/excel_community.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../domain/import_parser.dart';
import 'document_ocr.dart';

Future<List<ImportTable>> extractImportDocument(
  String name,
  Uint8List bytes, {
  void Function(String)? onProgress,
}) async {
  if (bytes.isEmpty) throw const FormatException('The file is empty.');
  if (bytes.length > 20 * 1024 * 1024) {
    throw const FormatException('Choose a file under 20 MB.');
  }
  final extension = name.split('.').last.toLowerCase();
  if (['csv', 'tsv', 'txt'].contains(extension)) {
    return [parseImportText(utf8.decode(bytes), name: name)];
  }
  if (extension == 'xlsx') return compute(extractImportSpreadsheet, bytes);
  if (extension == 'pdf') {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(bytes);
    final pages = <ImportTable>[];
    try {
      if (document.pages.length > 40) {
        throw const FormatException(
          'Split PDFs into files of at most 40 pages.',
        );
      }
      for (final page in document.pages) {
        onProgress?.call(
          'Reading PDF page ${page.pageNumber} of ${document.pages.length}',
        );
        final raw = await page.loadText();
        String text;
        if (raw != null && raw.fullText.trim().isNotEmpty) {
          final atoms = <PositionedImportText>[];
          for (final match in RegExp(r'\S+').allMatches(raw.fullText)) {
            if (match.end > raw.charRects.length) continue;
            final rects = raw.charRects
                .sublist(match.start, match.end)
                .where((rect) => rect.isNotEmpty);
            if (rects.isEmpty) continue;
            final box = rects.reduce((a, b) => a.merge(b));
            atoms.add(
              PositionedImportText(
                match.group(0)!,
                box.left,
                page.height - box.top,
                box.right,
                box.height,
              ),
            );
          }
          text = atoms.isEmpty ? raw.fullText : positionedImportText(atoms);
        } else {
          final rendered = await page.render(
            fullWidth: page.width * 2,
            fullHeight: page.height * 2,
          );
          if (rendered == null) {
            throw const FormatException('A PDF page could not be rendered.');
          }
          try {
            final image = await rendered.createImage();
            try {
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (png == null) {
                throw const FormatException(
                  'A scanned page could not be read.',
                );
              }
              text = await recognizeImportImage(
                png.buffer.asUint8List(),
                'png',
              );
            } finally {
              image.dispose();
            }
          } finally {
            rendered.dispose();
          }
        }
        if (text.trim().isNotEmpty) {
          pages.add(parseImportText(text, name: 'Page ${page.pageNumber}'));
        }
      }
    } finally {
      await document.dispose();
    }
    if (pages.isEmpty) {
      throw const FormatException('The PDF contains no readable records.');
    }
    return pages;
  }
  if (['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
    onProgress?.call('Recognizing text on this device…');
    return [
      parseImportText(await recognizeImportImage(bytes, extension), name: name),
    ];
  }
  throw const FormatException(
    'Choose CSV, TSV, XLSX, PDF, JPG, PNG, or WebP. Save old XLS workbooks as XLSX first.',
  );
}

List<ImportTable> extractImportSpreadsheet(Uint8List bytes) {
  final workbook = Excel.decodeBytes(bytes);
  final tables = <ImportTable>[];
  for (final sheet in workbook.tables.values) {
    final rows = <List<String>>[];
    for (final row in sheet.rows) {
      final cells = <String>[];
      for (final cell in row) {
        final value = cell?.value;
        if (value is FormulaCellValue) {
          throw const FormatException(
            'Replace spreadsheet formulas with their values before importing.',
          );
        }
        cells.add(value?.toString() ?? '');
      }
      if (cells.any((cell) => cell.trim().isNotEmpty)) rows.add(cells);
    }
    if (rows.isNotEmpty) tables.add(ImportTable(sheet.sheetName, rows));
  }
  if (tables.isEmpty) throw const FormatException('The workbook has no data.');
  return tables;
}
