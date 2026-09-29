import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../domain/import_parser.dart';

class ImportResult {
  const ImportResult(this.imported, this.updated, this.skipped);
  final int imported, updated, skipped;
}

final dataImportRepositoryProvider = Provider<DataImportRepository>(
  (ref) => DataImportRepository(Supabase.instance.client),
);

class DataImportRepository {
  DataImportRepository(this._client);
  final SupabaseClient _client;

  Future<ImportResult> commit({
    required String organizationId,
    required String venueId,
    required String dataset,
    required List<ImportPreviewRow> rows,
  }) async {
    try {
      final result = Map<String, dynamic>.from(
        await _client.rpc(
          'import_venue_data',
          params: {
            'p_organization_id': organizationId,
            'p_venue_id': venueId,
            'p_dataset': dataset,
            'p_rows': rows
                .map((row) => {...row.values, '__line': row.line.toString()})
                .toList(),
          },
        ) as Map,
      );
      return ImportResult(
        result['imported'] as int,
        result['updated'] as int,
        result['skipped'] as int,
      );
    } on PostgrestException catch (error) {
      if (error.message.startsWith('Import row ')) {
        throw ValidationFailure(error.message);
      }
      throw mapFailure(error);
    } catch (error) {
      throw mapFailure(error);
    }
  }
}
