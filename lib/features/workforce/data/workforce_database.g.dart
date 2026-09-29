// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workforce_database.dart';

// ignore_for_file: type=lint
class $WorkforceCacheTable extends WorkforceCache
    with TableInfo<$WorkforceCacheTable, WorkforceCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkforceCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snapshotMeta = const VerificationMeta(
    'snapshot',
  );
  @override
  late final GeneratedColumn<String> snapshot = GeneratedColumn<String>(
    'snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [scope, snapshot, capturedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workforce_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkforceCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('snapshot')) {
      context.handle(
        _snapshotMeta,
        snapshot.isAcceptableOrUnknown(data['snapshot']!, _snapshotMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope};
  @override
  WorkforceCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkforceCacheData(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      snapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
    );
  }

  @override
  $WorkforceCacheTable createAlias(String alias) {
    return $WorkforceCacheTable(attachedDatabase, alias);
  }
}

class WorkforceCacheData extends DataClass
    implements Insertable<WorkforceCacheData> {
  final String scope;
  final String snapshot;
  final DateTime capturedAt;
  const WorkforceCacheData({
    required this.scope,
    required this.snapshot,
    required this.capturedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['snapshot'] = Variable<String>(snapshot);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    return map;
  }

  WorkforceCacheCompanion toCompanion(bool nullToAbsent) {
    return WorkforceCacheCompanion(
      scope: Value(scope),
      snapshot: Value(snapshot),
      capturedAt: Value(capturedAt),
    );
  }

  factory WorkforceCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkforceCacheData(
      scope: serializer.fromJson<String>(json['scope']),
      snapshot: serializer.fromJson<String>(json['snapshot']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'snapshot': serializer.toJson<String>(snapshot),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
    };
  }

  WorkforceCacheData copyWith({
    String? scope,
    String? snapshot,
    DateTime? capturedAt,
  }) => WorkforceCacheData(
    scope: scope ?? this.scope,
    snapshot: snapshot ?? this.snapshot,
    capturedAt: capturedAt ?? this.capturedAt,
  );
  WorkforceCacheData copyWithCompanion(WorkforceCacheCompanion data) {
    return WorkforceCacheData(
      scope: data.scope.present ? data.scope.value : this.scope,
      snapshot: data.snapshot.present ? data.snapshot.value : this.snapshot,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkforceCacheData(')
          ..write('scope: $scope, ')
          ..write('snapshot: $snapshot, ')
          ..write('capturedAt: $capturedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, snapshot, capturedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkforceCacheData &&
          other.scope == this.scope &&
          other.snapshot == this.snapshot &&
          other.capturedAt == this.capturedAt);
}

class WorkforceCacheCompanion extends UpdateCompanion<WorkforceCacheData> {
  final Value<String> scope;
  final Value<String> snapshot;
  final Value<DateTime> capturedAt;
  final Value<int> rowid;
  const WorkforceCacheCompanion({
    this.scope = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkforceCacheCompanion.insert({
    required String scope,
    required String snapshot,
    required DateTime capturedAt,
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       snapshot = Value(snapshot),
       capturedAt = Value(capturedAt);
  static Insertable<WorkforceCacheData> custom({
    Expression<String>? scope,
    Expression<String>? snapshot,
    Expression<DateTime>? capturedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (snapshot != null) 'snapshot': snapshot,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkforceCacheCompanion copyWith({
    Value<String>? scope,
    Value<String>? snapshot,
    Value<DateTime>? capturedAt,
    Value<int>? rowid,
  }) {
    return WorkforceCacheCompanion(
      scope: scope ?? this.scope,
      snapshot: snapshot ?? this.snapshot,
      capturedAt: capturedAt ?? this.capturedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (snapshot.present) {
      map['snapshot'] = Variable<String>(snapshot.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkforceCacheCompanion(')
          ..write('scope: $scope, ')
          ..write('snapshot: $snapshot, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkforcePendingTable extends WorkforcePending
    with TableInfo<$WorkforcePendingTable, WorkforcePendingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkforcePendingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandMeta = const VerificationMeta(
    'command',
  );
  @override
  late final GeneratedColumn<String> command = GeneratedColumn<String>(
    'command',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, scope, command, status, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workforce_pending';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkforcePendingData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('command')) {
      context.handle(
        _commandMeta,
        command.isAcceptableOrUnknown(data['command']!, _commandMeta),
      );
    } else if (isInserting) {
      context.missing(_commandMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkforcePendingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkforcePendingData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      command: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorkforcePendingTable createAlias(String alias) {
    return $WorkforcePendingTable(attachedDatabase, alias);
  }
}

class WorkforcePendingData extends DataClass
    implements Insertable<WorkforcePendingData> {
  final String id;
  final String scope;
  final String command;
  final String status;
  final DateTime createdAt;
  const WorkforcePendingData({
    required this.id,
    required this.scope,
    required this.command,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scope'] = Variable<String>(scope);
    map['command'] = Variable<String>(command);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorkforcePendingCompanion toCompanion(bool nullToAbsent) {
    return WorkforcePendingCompanion(
      id: Value(id),
      scope: Value(scope),
      command: Value(command),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory WorkforcePendingData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkforcePendingData(
      id: serializer.fromJson<String>(json['id']),
      scope: serializer.fromJson<String>(json['scope']),
      command: serializer.fromJson<String>(json['command']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scope': serializer.toJson<String>(scope),
      'command': serializer.toJson<String>(command),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WorkforcePendingData copyWith({
    String? id,
    String? scope,
    String? command,
    String? status,
    DateTime? createdAt,
  }) => WorkforcePendingData(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    command: command ?? this.command,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  WorkforcePendingData copyWithCompanion(WorkforcePendingCompanion data) {
    return WorkforcePendingData(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      command: data.command.present ? data.command.value : this.command,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkforcePendingData(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('command: $command, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scope, command, status, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkforcePendingData &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.command == this.command &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class WorkforcePendingCompanion extends UpdateCompanion<WorkforcePendingData> {
  final Value<String> id;
  final Value<String> scope;
  final Value<String> command;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WorkforcePendingCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.command = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkforcePendingCompanion.insert({
    required String id,
    required String scope,
    required String command,
    required String status,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scope = Value(scope),
       command = Value(command),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<WorkforcePendingData> custom({
    Expression<String>? id,
    Expression<String>? scope,
    Expression<String>? command,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (command != null) 'command': command,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkforcePendingCompanion copyWith({
    Value<String>? id,
    Value<String>? scope,
    Value<String>? command,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WorkforcePendingCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      command: command ?? this.command,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (command.present) {
      map['command'] = Variable<String>(command.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkforcePendingCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('command: $command, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$WorkforceDatabase extends GeneratedDatabase {
  _$WorkforceDatabase(QueryExecutor e) : super(e);
  $WorkforceDatabaseManager get managers => $WorkforceDatabaseManager(this);
  late final $WorkforceCacheTable workforceCache = $WorkforceCacheTable(this);
  late final $WorkforcePendingTable workforcePending = $WorkforcePendingTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    workforceCache,
    workforcePending,
  ];
}

typedef $$WorkforceCacheTableCreateCompanionBuilder =
    WorkforceCacheCompanion Function({
      required String scope,
      required String snapshot,
      required DateTime capturedAt,
      Value<int> rowid,
    });
typedef $$WorkforceCacheTableUpdateCompanionBuilder =
    WorkforceCacheCompanion Function({
      Value<String> scope,
      Value<String> snapshot,
      Value<DateTime> capturedAt,
      Value<int> rowid,
    });

class $$WorkforceCacheTableFilterComposer
    extends Composer<_$WorkforceDatabase, $WorkforceCacheTable> {
  $$WorkforceCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkforceCacheTableOrderingComposer
    extends Composer<_$WorkforceDatabase, $WorkforceCacheTable> {
  $$WorkforceCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkforceCacheTableAnnotationComposer
    extends Composer<_$WorkforceDatabase, $WorkforceCacheTable> {
  $$WorkforceCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );
}

class $$WorkforceCacheTableTableManager
    extends
        RootTableManager<
          _$WorkforceDatabase,
          $WorkforceCacheTable,
          WorkforceCacheData,
          $$WorkforceCacheTableFilterComposer,
          $$WorkforceCacheTableOrderingComposer,
          $$WorkforceCacheTableAnnotationComposer,
          $$WorkforceCacheTableCreateCompanionBuilder,
          $$WorkforceCacheTableUpdateCompanionBuilder,
          (
            WorkforceCacheData,
            BaseReferences<
              _$WorkforceDatabase,
              $WorkforceCacheTable,
              WorkforceCacheData
            >,
          ),
          WorkforceCacheData,
          PrefetchHooks Function()
        > {
  $$WorkforceCacheTableTableManager(
    _$WorkforceDatabase db,
    $WorkforceCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkforceCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkforceCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkforceCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> snapshot = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkforceCacheCompanion(
                scope: scope,
                snapshot: snapshot,
                capturedAt: capturedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String snapshot,
                required DateTime capturedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkforceCacheCompanion.insert(
                scope: scope,
                snapshot: snapshot,
                capturedAt: capturedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkforceCacheTable, WorkforceCacheData>(table),
                  BaseReferences<
                    _$WorkforceDatabase,
                    $WorkforceCacheTable,
                    WorkforceCacheData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkforceCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$WorkforceDatabase,
      $WorkforceCacheTable,
      WorkforceCacheData,
      $$WorkforceCacheTableFilterComposer,
      $$WorkforceCacheTableOrderingComposer,
      $$WorkforceCacheTableAnnotationComposer,
      $$WorkforceCacheTableCreateCompanionBuilder,
      $$WorkforceCacheTableUpdateCompanionBuilder,
      (
        WorkforceCacheData,
        BaseReferences<
          _$WorkforceDatabase,
          $WorkforceCacheTable,
          WorkforceCacheData
        >,
      ),
      WorkforceCacheData,
      PrefetchHooks Function()
    >;
typedef $$WorkforcePendingTableCreateCompanionBuilder =
    WorkforcePendingCompanion Function({
      required String id,
      required String scope,
      required String command,
      required String status,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$WorkforcePendingTableUpdateCompanionBuilder =
    WorkforcePendingCompanion Function({
      Value<String> id,
      Value<String> scope,
      Value<String> command,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$WorkforcePendingTableFilterComposer
    extends Composer<_$WorkforceDatabase, $WorkforcePendingTable> {
  $$WorkforcePendingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkforcePendingTableOrderingComposer
    extends Composer<_$WorkforceDatabase, $WorkforcePendingTable> {
  $$WorkforcePendingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkforcePendingTableAnnotationComposer
    extends Composer<_$WorkforceDatabase, $WorkforcePendingTable> {
  $$WorkforcePendingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get command =>
      $composableBuilder(column: $table.command, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WorkforcePendingTableTableManager
    extends
        RootTableManager<
          _$WorkforceDatabase,
          $WorkforcePendingTable,
          WorkforcePendingData,
          $$WorkforcePendingTableFilterComposer,
          $$WorkforcePendingTableOrderingComposer,
          $$WorkforcePendingTableAnnotationComposer,
          $$WorkforcePendingTableCreateCompanionBuilder,
          $$WorkforcePendingTableUpdateCompanionBuilder,
          (
            WorkforcePendingData,
            BaseReferences<
              _$WorkforceDatabase,
              $WorkforcePendingTable,
              WorkforcePendingData
            >,
          ),
          WorkforcePendingData,
          PrefetchHooks Function()
        > {
  $$WorkforcePendingTableTableManager(
    _$WorkforceDatabase db,
    $WorkforcePendingTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkforcePendingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkforcePendingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkforcePendingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> command = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkforcePendingCompanion(
                id: id,
                scope: scope,
                command: command,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scope,
                required String command,
                required String status,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkforcePendingCompanion.insert(
                id: id,
                scope: scope,
                command: command,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkforcePendingTable, WorkforcePendingData>(
                    table,
                  ),
                  BaseReferences<
                    _$WorkforceDatabase,
                    $WorkforcePendingTable,
                    WorkforcePendingData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkforcePendingTableProcessedTableManager =
    ProcessedTableManager<
      _$WorkforceDatabase,
      $WorkforcePendingTable,
      WorkforcePendingData,
      $$WorkforcePendingTableFilterComposer,
      $$WorkforcePendingTableOrderingComposer,
      $$WorkforcePendingTableAnnotationComposer,
      $$WorkforcePendingTableCreateCompanionBuilder,
      $$WorkforcePendingTableUpdateCompanionBuilder,
      (
        WorkforcePendingData,
        BaseReferences<
          _$WorkforceDatabase,
          $WorkforcePendingTable,
          WorkforcePendingData
        >,
      ),
      WorkforcePendingData,
      PrefetchHooks Function()
    >;

class $WorkforceDatabaseManager {
  final _$WorkforceDatabase _db;
  $WorkforceDatabaseManager(this._db);
  $$WorkforceCacheTableTableManager get workforceCache =>
      $$WorkforceCacheTableTableManager(_db, _db.workforceCache);
  $$WorkforcePendingTableTableManager get workforcePending =>
      $$WorkforcePendingTableTableManager(_db, _db.workforcePending);
}
