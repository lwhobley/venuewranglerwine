import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/status_banner.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../../wine_inventory/application/cellar_controller.dart';
import '../data/document_extractor.dart';
import '../data/import_repository.dart';
import '../domain/import_parser.dart';
import '../domain/import_schema.dart';

class DataImportPage extends ConsumerStatefulWidget {
  const DataImportPage({super.key});
  @override
  ConsumerState<DataImportPage> createState() => _DataImportPageState();
}

class _DataImportPageState extends ConsumerState<DataImportPage> {
  final _text = TextEditingController();
  String _dataset = 'inventory';
  List<ImportTable> _sheets = [];
  int _sheet = 0;
  ImportTable? _table;
  int _header = 0;
  Map<String, int> _mapping = {};
  List<ImportPreviewRow> _preview = [];
  (String, String)? _reviewScope;
  bool _busy = false;
  String? _error;
  String? _message;
  String? _progress;
  ImportSchema get _schema =>
      importSchemas.firstWhere((schema) => schema.key == _dataset);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _setTable(ImportTable table) {
    _table = table;
    _header = table.suggestedHeader(_schema);
    _mapping = suggestImportMapping(_schema, table.rows[_header]);
    _preview = [];
    _reviewScope = null;
    _error = null;
    _message = null;
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'csv',
          'tsv',
          'txt',
          'xlsx',
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'webp',
        ],
      );
      if (file == null) return;
      final size = await file.length();
      if (size != null && size > 20 * 1024 * 1024) {
        throw const FormatException('Choose a file under 20 MB.');
      }
      final tables = await extractImportDocument(
        file.name,
        await file.readAsBytes(),
        onProgress: (message) {
          if (mounted) setState(() => _progress = message);
        },
      );
      if (!mounted) return;
      setState(() {
        _sheets = tables;
        _sheet = 0;
        _text.text = importTableText(tables.first.rows);
        _setTable(tables.first);
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : 'Could not read the file. Check its format and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  void _parse() {
    try {
      setState(() {
        _sheets = [];
        _setTable(parseImportText(_text.text));
      });
    } on FormatException catch (error) {
      setState(() => _error = error.message.toString());
    }
  }

  void _review() {
    try {
      final rows = previewImport(_schema, _table!, _header, _mapping);
      if (rows.isEmpty) {
        throw const FormatException(
          'No data rows were found below the selected header.',
        );
      }
      final valid = rows.every((row) => row.isValid);
      final ordered = _dataset == 'locations' && valid
          ? orderLocationRows(rows)
          : rows;
      final scope = ref.read(workspaceControllerProvider);
      setState(() {
        _preview = ordered;
        _reviewScope = (scope.organizationId!, scope.venueId!);
        _error = null;
        _message = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _preview = [];
        _error = error.message.toString();
      });
    }
  }

  Future<void> _commit() async {
    final scope = ref.read(workspaceControllerProvider);
    if (_reviewScope != (scope.organizationId, scope.venueId)) {
      setState(() => _error = 'The workspace changed. Review the rows again.');
      return;
    }
    final schema = _schema;
    final rows = List<ImportPreviewRow>.of(_preview);
    final tenant = ref.read(tenantControllerProvider).value!;
    final organization = tenant.organization(scope.organizationId)!;
    final venue = tenant.venues.firstWhere(
      (venue) => venue.id == scope.venueId,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import reviewed records?'),
        content: Text(
          '${rows.length} ${schema.label.toLowerCase()} rows will be saved to ${organization.name} / ${venue.name}.\n\n${schema.help}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final current = ref.read(workspaceControllerProvider);
    if (_reviewScope != (current.organizationId, current.venueId)) {
      setState(() => _error = 'The workspace changed. Review the rows again.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(dataImportRepositoryProvider)
          .commit(
            organizationId: scope.organizationId!,
            venueId: scope.venueId!,
            dataset: schema.key,
            rows: rows,
          );
      if (!mounted) return;
      ref.invalidate(cellarControllerProvider);
      ref.invalidate(tenantControllerProvider);
      if (mounted) {
        setState(() {
          _message =
              'Imported ${result.imported}, updated ${result.updated}, skipped ${result.skipped}. All rows saved successfully.';
          _preview = [];
        });
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _template(bool save) async {
    final data = importTableText([
      _schema.fields.map((field) => field.key).toList(),
    ]);
    try {
      if (save) {
        await FilePicker.saveFile(
          dialogTitle: 'Save CSV template',
          fileName: '$_dataset-template.csv',
          bytes: Uint8List.fromList(utf8.encode('$data\n')),
        );
      } else {
        await Clipboard.setData(ClipboardData(text: '$data\n'));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save or copy the template. Try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantControllerProvider).value;
    final scope = ref.watch(workspaceControllerProvider);
    if (tenant == null || scope.organizationId == null || scope.venueId == null) {
      return const Center(
        child: Text('Choose an organization and venue before importing.'),
      );
    }
    final allowed = importSchemas
        .where((schema) => tenant.can(scope.organizationId!, schema.permission))
        .toList();
    if (allowed.isEmpty) {
      return const Center(
        child: Text('You do not have permission to import data.'),
      );
    }
    final schema = allowed.firstWhere(
      (schema) => schema.key == _dataset,
      orElse: () => allowed.first,
    );
    if (schema.key != _dataset) {
      _dataset = schema.key;
      _table = null;
      _preview = [];
    }
    final venue = tenant.venues.firstWhere(
      (venue) => venue.id == scope.venueId,
    );
    final headers = _table?.rows[_header] ?? [];
    final invalid = _preview.where((row) => !row.isValid).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Import data', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '${tenant.organization(scope.organizationId)!.name} / ${venue.name}',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: schema.key,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'What are you importing?',
          ),
          items: [
            for (final item in allowed)
              DropdownMenuItem(value: item.key, child: Text(item.label)),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _dataset = value!;
                  if (_table != null) _setTable(_table!);
                }),
        ),
        const SizedBox(height: 12),
        Text(schema.help),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose file or photo'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _template(false),
              child: const Text('Copy CSV header'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _template(true),
              child: const Text('Save CSV template'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'CSV, Excel (.xlsx), text, PDF, and photos · 20 MB maximum. Photos and scanned PDFs are recognized on Android/iOS. Extracted data stays on this device until you import.',
        ),
        if (_busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          Text(_progress ?? 'Working…'),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          StatusBanner(message: _error!),
        ],
        if (_message != null) ...[
          const SizedBox(height: 12),
          StatusBanner(message: _message!, tone: BannerTone.success),
        ],
        if (_sheets.length > 1) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _sheet,
            decoration: const InputDecoration(
              labelText: 'Worksheet / PDF page (import each separately)',
            ),
            items: [
              for (var i = 0; i < _sheets.length; i++)
                DropdownMenuItem(value: i, child: Text(_sheets[i].name)),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _sheet = value!;
                    _text.text = importTableText(_sheets[_sheet].rows);
                    _setTable(_sheets[_sheet]);
                  }),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          enabled: !_busy,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Paste data or correct extracted text',
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {
            _table = null;
            _preview = [];
            _message = null;
          }),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : _parse,
          child: const Text('Parse and map fields'),
        ),
        if (_table != null) ...[
          const SizedBox(height: 24),
          Text('Map fields', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey((_table, _header)),
            initialValue: _header,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Header row'),
            items: [
              for (var i = 0; i < _table!.rows.length && i < 20; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${i + 1}: ${_table!.rows[i].join(' · ')}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _header = value!;
                    _mapping = suggestImportMapping(
                      schema,
                      _table!.rows[_header],
                    );
                    _preview = [];
                  }),
          ),
          for (final field in schema.fields)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DropdownButtonFormField<int>(
                key: ValueKey((
                  _table,
                  _header,
                  _dataset,
                  field.key,
                  _mapping[field.key],
                )),
                initialValue: _mapping[field.key] ?? -1,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: field.label + (field.required ? ' *' : ''),
                ),
                items: [
                  DropdownMenuItem(
                    value: -1,
                    child: Text(
                      field.defaultValue.isEmpty
                          ? 'Not mapped'
                          : 'Default: ${field.defaultValue}',
                    ),
                  ),
                  for (var i = 0; i < headers.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${i + 1}: ${headers[i]}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        if (value == -1) {
                          _mapping.remove(field.key);
                        } else {
                          _mapping[field.key] = value!;
                        }
                        _preview = [];
                      }),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _review,
            child: const Text('Review rows'),
          ),
        ],
        if (_preview.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            '${_preview.length} rows · ${invalid.length} need correction',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final row in invalid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: StatusBanner(
                message: 'Row ${row.line}: ${row.errors.join(' ')}',
              ),
            ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Row')),
                for (final field in schema.fields)
                  DataColumn(label: Text(field.label)),
              ],
              rows: [
                for (final row in _preview.take(50))
                  DataRow(
                    cells: [
                      DataCell(Text(row.line.toString())),
                      for (final field in schema.fields)
                        DataCell(
                          SizedBox(
                            width: 160,
                            child: Text(
                              row.values[field.key] ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (_preview.length > 50)
            const Text(
              'Preview shows the first 50 rows. Every row is validated and included in the import.',
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || invalid.isNotEmpty ? null : _commit,
            child: Text('Import ${_preview.length} reviewed rows'),
          ),
        ],
      ],
    );
  }
}
