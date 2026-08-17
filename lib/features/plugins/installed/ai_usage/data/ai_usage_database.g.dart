// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_usage_database.dart';

// ignore_for_file: type=lint
class $AiUsageTurnsTable extends AiUsageTurns
    with TableInfo<$AiUsageTurnsTable, AiUsageTurn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiUsageTurnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputTokensMeta = const VerificationMeta(
    'inputTokens',
  );
  @override
  late final GeneratedColumn<int> inputTokens = GeneratedColumn<int>(
    'input_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _outputTokensMeta = const VerificationMeta(
    'outputTokens',
  );
  @override
  late final GeneratedColumn<int> outputTokens = GeneratedColumn<int>(
    'output_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cacheReadTokensMeta = const VerificationMeta(
    'cacheReadTokens',
  );
  @override
  late final GeneratedColumn<int> cacheReadTokens = GeneratedColumn<int>(
    'cache_read_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cacheCreationTokensMeta =
      const VerificationMeta('cacheCreationTokens');
  @override
  late final GeneratedColumn<int> cacheCreationTokens = GeneratedColumn<int>(
    'cache_creation_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectMeta = const VerificationMeta(
    'project',
  );
  @override
  late final GeneratedColumn<String> project = GeneratedColumn<String>(
    'project',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AiUsageSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AiUsageSource>($AiUsageTurnsTable.$convertersource);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    timestamp,
    model,
    inputTokens,
    outputTokens,
    cacheReadTokens,
    cacheCreationTokens,
    messageId,
    project,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_usage_turns';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiUsageTurn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('input_tokens')) {
      context.handle(
        _inputTokensMeta,
        inputTokens.isAcceptableOrUnknown(
          data['input_tokens']!,
          _inputTokensMeta,
        ),
      );
    }
    if (data.containsKey('output_tokens')) {
      context.handle(
        _outputTokensMeta,
        outputTokens.isAcceptableOrUnknown(
          data['output_tokens']!,
          _outputTokensMeta,
        ),
      );
    }
    if (data.containsKey('cache_read_tokens')) {
      context.handle(
        _cacheReadTokensMeta,
        cacheReadTokens.isAcceptableOrUnknown(
          data['cache_read_tokens']!,
          _cacheReadTokensMeta,
        ),
      );
    }
    if (data.containsKey('cache_creation_tokens')) {
      context.handle(
        _cacheCreationTokensMeta,
        cacheCreationTokens.isAcceptableOrUnknown(
          data['cache_creation_tokens']!,
          _cacheCreationTokensMeta,
        ),
      );
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    }
    if (data.containsKey('project')) {
      context.handle(
        _projectMeta,
        project.isAcceptableOrUnknown(data['project']!, _projectMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiUsageTurn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiUsageTurn(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      inputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_tokens'],
      )!,
      outputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_tokens'],
      )!,
      cacheReadTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cache_read_tokens'],
      )!,
      cacheCreationTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cache_creation_tokens'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      ),
      project: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project'],
      ),
      source: $AiUsageTurnsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
    );
  }

  @override
  $AiUsageTurnsTable createAlias(String alias) {
    return $AiUsageTurnsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AiUsageSource, String, String> $convertersource =
      const EnumNameConverter<AiUsageSource>(AiUsageSource.values);
}

class AiUsageTurn extends DataClass implements Insertable<AiUsageTurn> {
  final int id;
  final String sessionId;
  final DateTime timestamp;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final String? messageId;
  final String? project;
  final AiUsageSource source;
  const AiUsageTurn({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheCreationTokens,
    this.messageId,
    this.project,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['model'] = Variable<String>(model);
    map['input_tokens'] = Variable<int>(inputTokens);
    map['output_tokens'] = Variable<int>(outputTokens);
    map['cache_read_tokens'] = Variable<int>(cacheReadTokens);
    map['cache_creation_tokens'] = Variable<int>(cacheCreationTokens);
    if (!nullToAbsent || messageId != null) {
      map['message_id'] = Variable<String>(messageId);
    }
    if (!nullToAbsent || project != null) {
      map['project'] = Variable<String>(project);
    }
    {
      map['source'] = Variable<String>(
        $AiUsageTurnsTable.$convertersource.toSql(source),
      );
    }
    return map;
  }

  AiUsageTurnsCompanion toCompanion(bool nullToAbsent) {
    return AiUsageTurnsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      timestamp: Value(timestamp),
      model: Value(model),
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
      cacheReadTokens: Value(cacheReadTokens),
      cacheCreationTokens: Value(cacheCreationTokens),
      messageId: messageId == null && nullToAbsent
          ? const Value.absent()
          : Value(messageId),
      project: project == null && nullToAbsent
          ? const Value.absent()
          : Value(project),
      source: Value(source),
    );
  }

  factory AiUsageTurn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiUsageTurn(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      model: serializer.fromJson<String>(json['model']),
      inputTokens: serializer.fromJson<int>(json['inputTokens']),
      outputTokens: serializer.fromJson<int>(json['outputTokens']),
      cacheReadTokens: serializer.fromJson<int>(json['cacheReadTokens']),
      cacheCreationTokens: serializer.fromJson<int>(
        json['cacheCreationTokens'],
      ),
      messageId: serializer.fromJson<String?>(json['messageId']),
      project: serializer.fromJson<String?>(json['project']),
      source: $AiUsageTurnsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'model': serializer.toJson<String>(model),
      'inputTokens': serializer.toJson<int>(inputTokens),
      'outputTokens': serializer.toJson<int>(outputTokens),
      'cacheReadTokens': serializer.toJson<int>(cacheReadTokens),
      'cacheCreationTokens': serializer.toJson<int>(cacheCreationTokens),
      'messageId': serializer.toJson<String?>(messageId),
      'project': serializer.toJson<String?>(project),
      'source': serializer.toJson<String>(
        $AiUsageTurnsTable.$convertersource.toJson(source),
      ),
    };
  }

  AiUsageTurn copyWith({
    int? id,
    String? sessionId,
    DateTime? timestamp,
    String? model,
    int? inputTokens,
    int? outputTokens,
    int? cacheReadTokens,
    int? cacheCreationTokens,
    Value<String?> messageId = const Value.absent(),
    Value<String?> project = const Value.absent(),
    AiUsageSource? source,
  }) => AiUsageTurn(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    timestamp: timestamp ?? this.timestamp,
    model: model ?? this.model,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    cacheReadTokens: cacheReadTokens ?? this.cacheReadTokens,
    cacheCreationTokens: cacheCreationTokens ?? this.cacheCreationTokens,
    messageId: messageId.present ? messageId.value : this.messageId,
    project: project.present ? project.value : this.project,
    source: source ?? this.source,
  );
  AiUsageTurn copyWithCompanion(AiUsageTurnsCompanion data) {
    return AiUsageTurn(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      model: data.model.present ? data.model.value : this.model,
      inputTokens: data.inputTokens.present
          ? data.inputTokens.value
          : this.inputTokens,
      outputTokens: data.outputTokens.present
          ? data.outputTokens.value
          : this.outputTokens,
      cacheReadTokens: data.cacheReadTokens.present
          ? data.cacheReadTokens.value
          : this.cacheReadTokens,
      cacheCreationTokens: data.cacheCreationTokens.present
          ? data.cacheCreationTokens.value
          : this.cacheCreationTokens,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      project: data.project.present ? data.project.value : this.project,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiUsageTurn(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestamp: $timestamp, ')
          ..write('model: $model, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('cacheReadTokens: $cacheReadTokens, ')
          ..write('cacheCreationTokens: $cacheCreationTokens, ')
          ..write('messageId: $messageId, ')
          ..write('project: $project, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    timestamp,
    model,
    inputTokens,
    outputTokens,
    cacheReadTokens,
    cacheCreationTokens,
    messageId,
    project,
    source,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiUsageTurn &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.timestamp == this.timestamp &&
          other.model == this.model &&
          other.inputTokens == this.inputTokens &&
          other.outputTokens == this.outputTokens &&
          other.cacheReadTokens == this.cacheReadTokens &&
          other.cacheCreationTokens == this.cacheCreationTokens &&
          other.messageId == this.messageId &&
          other.project == this.project &&
          other.source == this.source);
}

class AiUsageTurnsCompanion extends UpdateCompanion<AiUsageTurn> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<DateTime> timestamp;
  final Value<String> model;
  final Value<int> inputTokens;
  final Value<int> outputTokens;
  final Value<int> cacheReadTokens;
  final Value<int> cacheCreationTokens;
  final Value<String?> messageId;
  final Value<String?> project;
  final Value<AiUsageSource> source;
  const AiUsageTurnsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.model = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.cacheReadTokens = const Value.absent(),
    this.cacheCreationTokens = const Value.absent(),
    this.messageId = const Value.absent(),
    this.project = const Value.absent(),
    this.source = const Value.absent(),
  });
  AiUsageTurnsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required DateTime timestamp,
    required String model,
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.cacheReadTokens = const Value.absent(),
    this.cacheCreationTokens = const Value.absent(),
    this.messageId = const Value.absent(),
    this.project = const Value.absent(),
    required AiUsageSource source,
  }) : sessionId = Value(sessionId),
       timestamp = Value(timestamp),
       model = Value(model),
       source = Value(source);
  static Insertable<AiUsageTurn> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<DateTime>? timestamp,
    Expression<String>? model,
    Expression<int>? inputTokens,
    Expression<int>? outputTokens,
    Expression<int>? cacheReadTokens,
    Expression<int>? cacheCreationTokens,
    Expression<String>? messageId,
    Expression<String>? project,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (timestamp != null) 'timestamp': timestamp,
      if (model != null) 'model': model,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      if (cacheReadTokens != null) 'cache_read_tokens': cacheReadTokens,
      if (cacheCreationTokens != null)
        'cache_creation_tokens': cacheCreationTokens,
      if (messageId != null) 'message_id': messageId,
      if (project != null) 'project': project,
      if (source != null) 'source': source,
    });
  }

  AiUsageTurnsCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<DateTime>? timestamp,
    Value<String>? model,
    Value<int>? inputTokens,
    Value<int>? outputTokens,
    Value<int>? cacheReadTokens,
    Value<int>? cacheCreationTokens,
    Value<String?>? messageId,
    Value<String?>? project,
    Value<AiUsageSource>? source,
  }) {
    return AiUsageTurnsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      model: model ?? this.model,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      cacheReadTokens: cacheReadTokens ?? this.cacheReadTokens,
      cacheCreationTokens: cacheCreationTokens ?? this.cacheCreationTokens,
      messageId: messageId ?? this.messageId,
      project: project ?? this.project,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (inputTokens.present) {
      map['input_tokens'] = Variable<int>(inputTokens.value);
    }
    if (outputTokens.present) {
      map['output_tokens'] = Variable<int>(outputTokens.value);
    }
    if (cacheReadTokens.present) {
      map['cache_read_tokens'] = Variable<int>(cacheReadTokens.value);
    }
    if (cacheCreationTokens.present) {
      map['cache_creation_tokens'] = Variable<int>(cacheCreationTokens.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (project.present) {
      map['project'] = Variable<String>(project.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $AiUsageTurnsTable.$convertersource.toSql(source.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiUsageTurnsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestamp: $timestamp, ')
          ..write('model: $model, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('cacheReadTokens: $cacheReadTokens, ')
          ..write('cacheCreationTokens: $cacheCreationTokens, ')
          ..write('messageId: $messageId, ')
          ..write('project: $project, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $AiUsageScanFilesTable extends AiUsageScanFiles
    with TableInfo<$AiUsageScanFilesTable, AiUsageScanFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiUsageScanFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mtimeMsMeta = const VerificationMeta(
    'mtimeMs',
  );
  @override
  late final GeneratedColumn<double> mtimeMs = GeneratedColumn<double>(
    'mtime_ms',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineCountMeta = const VerificationMeta(
    'lineCount',
  );
  @override
  late final GeneratedColumn<int> lineCount = GeneratedColumn<int>(
    'line_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [path, mtimeMs, lineCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_usage_scan_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiUsageScanFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('mtime_ms')) {
      context.handle(
        _mtimeMsMeta,
        mtimeMs.isAcceptableOrUnknown(data['mtime_ms']!, _mtimeMsMeta),
      );
    } else if (isInserting) {
      context.missing(_mtimeMsMeta);
    }
    if (data.containsKey('line_count')) {
      context.handle(
        _lineCountMeta,
        lineCount.isAcceptableOrUnknown(data['line_count']!, _lineCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  AiUsageScanFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiUsageScanFile(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      mtimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mtime_ms'],
      )!,
      lineCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_count'],
      )!,
    );
  }

  @override
  $AiUsageScanFilesTable createAlias(String alias) {
    return $AiUsageScanFilesTable(attachedDatabase, alias);
  }
}

class AiUsageScanFile extends DataClass implements Insertable<AiUsageScanFile> {
  final String path;
  final double mtimeMs;
  final int lineCount;
  const AiUsageScanFile({
    required this.path,
    required this.mtimeMs,
    required this.lineCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['mtime_ms'] = Variable<double>(mtimeMs);
    map['line_count'] = Variable<int>(lineCount);
    return map;
  }

  AiUsageScanFilesCompanion toCompanion(bool nullToAbsent) {
    return AiUsageScanFilesCompanion(
      path: Value(path),
      mtimeMs: Value(mtimeMs),
      lineCount: Value(lineCount),
    );
  }

  factory AiUsageScanFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiUsageScanFile(
      path: serializer.fromJson<String>(json['path']),
      mtimeMs: serializer.fromJson<double>(json['mtimeMs']),
      lineCount: serializer.fromJson<int>(json['lineCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'mtimeMs': serializer.toJson<double>(mtimeMs),
      'lineCount': serializer.toJson<int>(lineCount),
    };
  }

  AiUsageScanFile copyWith({String? path, double? mtimeMs, int? lineCount}) =>
      AiUsageScanFile(
        path: path ?? this.path,
        mtimeMs: mtimeMs ?? this.mtimeMs,
        lineCount: lineCount ?? this.lineCount,
      );
  AiUsageScanFile copyWithCompanion(AiUsageScanFilesCompanion data) {
    return AiUsageScanFile(
      path: data.path.present ? data.path.value : this.path,
      mtimeMs: data.mtimeMs.present ? data.mtimeMs.value : this.mtimeMs,
      lineCount: data.lineCount.present ? data.lineCount.value : this.lineCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiUsageScanFile(')
          ..write('path: $path, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('lineCount: $lineCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, mtimeMs, lineCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiUsageScanFile &&
          other.path == this.path &&
          other.mtimeMs == this.mtimeMs &&
          other.lineCount == this.lineCount);
}

class AiUsageScanFilesCompanion extends UpdateCompanion<AiUsageScanFile> {
  final Value<String> path;
  final Value<double> mtimeMs;
  final Value<int> lineCount;
  final Value<int> rowid;
  const AiUsageScanFilesCompanion({
    this.path = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.lineCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiUsageScanFilesCompanion.insert({
    required String path,
    required double mtimeMs,
    this.lineCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       mtimeMs = Value(mtimeMs);
  static Insertable<AiUsageScanFile> custom({
    Expression<String>? path,
    Expression<double>? mtimeMs,
    Expression<int>? lineCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (mtimeMs != null) 'mtime_ms': mtimeMs,
      if (lineCount != null) 'line_count': lineCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiUsageScanFilesCompanion copyWith({
    Value<String>? path,
    Value<double>? mtimeMs,
    Value<int>? lineCount,
    Value<int>? rowid,
  }) {
    return AiUsageScanFilesCompanion(
      path: path ?? this.path,
      mtimeMs: mtimeMs ?? this.mtimeMs,
      lineCount: lineCount ?? this.lineCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (mtimeMs.present) {
      map['mtime_ms'] = Variable<double>(mtimeMs.value);
    }
    if (lineCount.present) {
      map['line_count'] = Variable<int>(lineCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiUsageScanFilesCompanion(')
          ..write('path: $path, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('lineCount: $lineCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AiUsageDatabase extends GeneratedDatabase {
  _$AiUsageDatabase(QueryExecutor e) : super(e);
  $AiUsageDatabaseManager get managers => $AiUsageDatabaseManager(this);
  late final $AiUsageTurnsTable aiUsageTurns = $AiUsageTurnsTable(this);
  late final $AiUsageScanFilesTable aiUsageScanFiles = $AiUsageScanFilesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    aiUsageTurns,
    aiUsageScanFiles,
  ];
}

typedef $$AiUsageTurnsTableCreateCompanionBuilder =
    AiUsageTurnsCompanion Function({
      Value<int> id,
      required String sessionId,
      required DateTime timestamp,
      required String model,
      Value<int> inputTokens,
      Value<int> outputTokens,
      Value<int> cacheReadTokens,
      Value<int> cacheCreationTokens,
      Value<String?> messageId,
      Value<String?> project,
      required AiUsageSource source,
    });
typedef $$AiUsageTurnsTableUpdateCompanionBuilder =
    AiUsageTurnsCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<DateTime> timestamp,
      Value<String> model,
      Value<int> inputTokens,
      Value<int> outputTokens,
      Value<int> cacheReadTokens,
      Value<int> cacheCreationTokens,
      Value<String?> messageId,
      Value<String?> project,
      Value<AiUsageSource> source,
    });

class $$AiUsageTurnsTableFilterComposer
    extends Composer<_$AiUsageDatabase, $AiUsageTurnsTable> {
  $$AiUsageTurnsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cacheReadTokens => $composableBuilder(
    column: $table.cacheReadTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cacheCreationTokens => $composableBuilder(
    column: $table.cacheCreationTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get project => $composableBuilder(
    column: $table.project,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AiUsageSource, AiUsageSource, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$AiUsageTurnsTableOrderingComposer
    extends Composer<_$AiUsageDatabase, $AiUsageTurnsTable> {
  $$AiUsageTurnsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cacheReadTokens => $composableBuilder(
    column: $table.cacheReadTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cacheCreationTokens => $composableBuilder(
    column: $table.cacheCreationTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get project => $composableBuilder(
    column: $table.project,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiUsageTurnsTableAnnotationComposer
    extends Composer<_$AiUsageDatabase, $AiUsageTurnsTable> {
  $$AiUsageTurnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cacheReadTokens => $composableBuilder(
    column: $table.cacheReadTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cacheCreationTokens => $composableBuilder(
    column: $table.cacheCreationTokens,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get project =>
      $composableBuilder(column: $table.project, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AiUsageSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$AiUsageTurnsTableTableManager
    extends
        RootTableManager<
          _$AiUsageDatabase,
          $AiUsageTurnsTable,
          AiUsageTurn,
          $$AiUsageTurnsTableFilterComposer,
          $$AiUsageTurnsTableOrderingComposer,
          $$AiUsageTurnsTableAnnotationComposer,
          $$AiUsageTurnsTableCreateCompanionBuilder,
          $$AiUsageTurnsTableUpdateCompanionBuilder,
          (
            AiUsageTurn,
            BaseReferences<_$AiUsageDatabase, $AiUsageTurnsTable, AiUsageTurn>,
          ),
          AiUsageTurn,
          PrefetchHooks Function()
        > {
  $$AiUsageTurnsTableTableManager(
    _$AiUsageDatabase db,
    $AiUsageTurnsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiUsageTurnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiUsageTurnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiUsageTurnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> inputTokens = const Value.absent(),
                Value<int> outputTokens = const Value.absent(),
                Value<int> cacheReadTokens = const Value.absent(),
                Value<int> cacheCreationTokens = const Value.absent(),
                Value<String?> messageId = const Value.absent(),
                Value<String?> project = const Value.absent(),
                Value<AiUsageSource> source = const Value.absent(),
              }) => AiUsageTurnsCompanion(
                id: id,
                sessionId: sessionId,
                timestamp: timestamp,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheReadTokens: cacheReadTokens,
                cacheCreationTokens: cacheCreationTokens,
                messageId: messageId,
                project: project,
                source: source,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required DateTime timestamp,
                required String model,
                Value<int> inputTokens = const Value.absent(),
                Value<int> outputTokens = const Value.absent(),
                Value<int> cacheReadTokens = const Value.absent(),
                Value<int> cacheCreationTokens = const Value.absent(),
                Value<String?> messageId = const Value.absent(),
                Value<String?> project = const Value.absent(),
                required AiUsageSource source,
              }) => AiUsageTurnsCompanion.insert(
                id: id,
                sessionId: sessionId,
                timestamp: timestamp,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheReadTokens: cacheReadTokens,
                cacheCreationTokens: cacheCreationTokens,
                messageId: messageId,
                project: project,
                source: source,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiUsageTurnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AiUsageDatabase,
      $AiUsageTurnsTable,
      AiUsageTurn,
      $$AiUsageTurnsTableFilterComposer,
      $$AiUsageTurnsTableOrderingComposer,
      $$AiUsageTurnsTableAnnotationComposer,
      $$AiUsageTurnsTableCreateCompanionBuilder,
      $$AiUsageTurnsTableUpdateCompanionBuilder,
      (
        AiUsageTurn,
        BaseReferences<_$AiUsageDatabase, $AiUsageTurnsTable, AiUsageTurn>,
      ),
      AiUsageTurn,
      PrefetchHooks Function()
    >;
typedef $$AiUsageScanFilesTableCreateCompanionBuilder =
    AiUsageScanFilesCompanion Function({
      required String path,
      required double mtimeMs,
      Value<int> lineCount,
      Value<int> rowid,
    });
typedef $$AiUsageScanFilesTableUpdateCompanionBuilder =
    AiUsageScanFilesCompanion Function({
      Value<String> path,
      Value<double> mtimeMs,
      Value<int> lineCount,
      Value<int> rowid,
    });

class $$AiUsageScanFilesTableFilterComposer
    extends Composer<_$AiUsageDatabase, $AiUsageScanFilesTable> {
  $$AiUsageScanFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiUsageScanFilesTableOrderingComposer
    extends Composer<_$AiUsageDatabase, $AiUsageScanFilesTable> {
  $$AiUsageScanFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiUsageScanFilesTableAnnotationComposer
    extends Composer<_$AiUsageDatabase, $AiUsageScanFilesTable> {
  $$AiUsageScanFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<double> get mtimeMs =>
      $composableBuilder(column: $table.mtimeMs, builder: (column) => column);

  GeneratedColumn<int> get lineCount =>
      $composableBuilder(column: $table.lineCount, builder: (column) => column);
}

class $$AiUsageScanFilesTableTableManager
    extends
        RootTableManager<
          _$AiUsageDatabase,
          $AiUsageScanFilesTable,
          AiUsageScanFile,
          $$AiUsageScanFilesTableFilterComposer,
          $$AiUsageScanFilesTableOrderingComposer,
          $$AiUsageScanFilesTableAnnotationComposer,
          $$AiUsageScanFilesTableCreateCompanionBuilder,
          $$AiUsageScanFilesTableUpdateCompanionBuilder,
          (
            AiUsageScanFile,
            BaseReferences<
              _$AiUsageDatabase,
              $AiUsageScanFilesTable,
              AiUsageScanFile
            >,
          ),
          AiUsageScanFile,
          PrefetchHooks Function()
        > {
  $$AiUsageScanFilesTableTableManager(
    _$AiUsageDatabase db,
    $AiUsageScanFilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiUsageScanFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiUsageScanFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiUsageScanFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<double> mtimeMs = const Value.absent(),
                Value<int> lineCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiUsageScanFilesCompanion(
                path: path,
                mtimeMs: mtimeMs,
                lineCount: lineCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required double mtimeMs,
                Value<int> lineCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiUsageScanFilesCompanion.insert(
                path: path,
                mtimeMs: mtimeMs,
                lineCount: lineCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiUsageScanFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AiUsageDatabase,
      $AiUsageScanFilesTable,
      AiUsageScanFile,
      $$AiUsageScanFilesTableFilterComposer,
      $$AiUsageScanFilesTableOrderingComposer,
      $$AiUsageScanFilesTableAnnotationComposer,
      $$AiUsageScanFilesTableCreateCompanionBuilder,
      $$AiUsageScanFilesTableUpdateCompanionBuilder,
      (
        AiUsageScanFile,
        BaseReferences<
          _$AiUsageDatabase,
          $AiUsageScanFilesTable,
          AiUsageScanFile
        >,
      ),
      AiUsageScanFile,
      PrefetchHooks Function()
    >;

class $AiUsageDatabaseManager {
  final _$AiUsageDatabase _db;
  $AiUsageDatabaseManager(this._db);
  $$AiUsageTurnsTableTableManager get aiUsageTurns =>
      $$AiUsageTurnsTableTableManager(_db, _db.aiUsageTurns);
  $$AiUsageScanFilesTableTableManager get aiUsageScanFiles =>
      $$AiUsageScanFilesTableTableManager(_db, _db.aiUsageScanFiles);
}
