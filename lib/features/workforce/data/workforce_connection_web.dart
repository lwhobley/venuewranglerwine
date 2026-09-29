import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor workforceConnection() => DatabaseConnection.delayed(
  WasmDatabase.open(
    databaseName: 'venue-wrangler-workforce',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  ).then((result) => result.resolvedExecutor),
);
