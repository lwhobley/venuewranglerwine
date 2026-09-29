import 'package:drift/drift.dart';
part 'workforce_database.g.dart';

class WorkforceCache extends Table {
  TextColumn get scope => text()();
  TextColumn get snapshot => text()();
  DateTimeColumn get capturedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {scope};
}

class WorkforcePending extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get command => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [WorkforceCache, WorkforcePending])
class WorkforceDatabase extends _$WorkforceDatabase {
  WorkforceDatabase(super.e);
  @override
  int get schemaVersion => 1;
  Future<void> clear() => transaction(() async {
    await delete(workforceCache).go();
    await delete(workforcePending).go();
  });
}
