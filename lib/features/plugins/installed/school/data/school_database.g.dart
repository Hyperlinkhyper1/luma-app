// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'school_database.dart';

// ignore_for_file: type=lint
class $SchoolSubjectsTable extends SchoolSubjects
    with TableInfo<$SchoolSubjectsTable, SchoolSubject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchoolSubjectsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF7C5AD9),
  );
  static const VerificationMeta _creditHoursMeta = const VerificationMeta(
    'creditHours',
  );
  @override
  late final GeneratedColumn<double> creditHours = GeneratedColumn<double>(
    'credit_hours',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    creditHours,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'school_subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<SchoolSubject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('credit_hours')) {
      context.handle(
        _creditHoursMeta,
        creditHours.isAcceptableOrUnknown(
          data['credit_hours']!,
          _creditHoursMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SchoolSubject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SchoolSubject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      creditHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}credit_hours'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $SchoolSubjectsTable createAlias(String alias) {
    return $SchoolSubjectsTable(attachedDatabase, alias);
  }
}

class SchoolSubject extends DataClass implements Insertable<SchoolSubject> {
  final int id;
  final String name;
  final int color;
  final double creditHours;
  final bool archived;
  const SchoolSubject({
    required this.id,
    required this.name,
    required this.color,
    required this.creditHours,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['credit_hours'] = Variable<double>(creditHours);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  SchoolSubjectsCompanion toCompanion(bool nullToAbsent) {
    return SchoolSubjectsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      creditHours: Value(creditHours),
      archived: Value(archived),
    );
  }

  factory SchoolSubject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SchoolSubject(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      creditHours: serializer.fromJson<double>(json['creditHours']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'creditHours': serializer.toJson<double>(creditHours),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  SchoolSubject copyWith({
    int? id,
    String? name,
    int? color,
    double? creditHours,
    bool? archived,
  }) => SchoolSubject(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    creditHours: creditHours ?? this.creditHours,
    archived: archived ?? this.archived,
  );
  SchoolSubject copyWithCompanion(SchoolSubjectsCompanion data) {
    return SchoolSubject(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      creditHours: data.creditHours.present
          ? data.creditHours.value
          : this.creditHours,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SchoolSubject(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('creditHours: $creditHours, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, creditHours, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchoolSubject &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.creditHours == this.creditHours &&
          other.archived == this.archived);
}

class SchoolSubjectsCompanion extends UpdateCompanion<SchoolSubject> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> color;
  final Value<double> creditHours;
  final Value<bool> archived;
  const SchoolSubjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.creditHours = const Value.absent(),
    this.archived = const Value.absent(),
  });
  SchoolSubjectsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.creditHours = const Value.absent(),
    this.archived = const Value.absent(),
  }) : name = Value(name);
  static Insertable<SchoolSubject> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<double>? creditHours,
    Expression<bool>? archived,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (creditHours != null) 'credit_hours': creditHours,
      if (archived != null) 'archived': archived,
    });
  }

  SchoolSubjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? color,
    Value<double>? creditHours,
    Value<bool>? archived,
  }) {
    return SchoolSubjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      creditHours: creditHours ?? this.creditHours,
      archived: archived ?? this.archived,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (creditHours.present) {
      map['credit_hours'] = Variable<double>(creditHours.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchoolSubjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('creditHours: $creditHours, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }
}

class $AssignmentsTable extends Assignments
    with TableInfo<$AssignmentsTable, Assignment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssignmentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES school_subjects (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradeEarnedMeta = const VerificationMeta(
    'gradeEarned',
  );
  @override
  late final GeneratedColumn<double> gradeEarned = GeneratedColumn<double>(
    'grade_earned',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradeTotalMeta = const VerificationMeta(
    'gradeTotal',
  );
  @override
  late final GeneratedColumn<double> gradeTotal = GeneratedColumn<double>(
    'grade_total',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    title,
    notes,
    dueDate,
    priority,
    completed,
    completedAt,
    gradeEarned,
    gradeTotal,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Assignment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('grade_earned')) {
      context.handle(
        _gradeEarnedMeta,
        gradeEarned.isAcceptableOrUnknown(
          data['grade_earned']!,
          _gradeEarnedMeta,
        ),
      );
    }
    if (data.containsKey('grade_total')) {
      context.handle(
        _gradeTotalMeta,
        gradeTotal.isAcceptableOrUnknown(data['grade_total']!, _gradeTotalMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Assignment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Assignment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      gradeEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grade_earned'],
      ),
      gradeTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grade_total'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AssignmentsTable createAlias(String alias) {
    return $AssignmentsTable(attachedDatabase, alias);
  }
}

class Assignment extends DataClass implements Insertable<Assignment> {
  final int id;
  final int? subjectId;
  final String title;
  final String? notes;
  final DateTime dueDate;
  final int priority;
  final bool completed;
  final DateTime? completedAt;
  final double? gradeEarned;
  final double? gradeTotal;
  final DateTime createdAt;
  const Assignment({
    required this.id,
    this.subjectId,
    required this.title,
    this.notes,
    required this.dueDate,
    required this.priority,
    required this.completed,
    this.completedAt,
    this.gradeEarned,
    this.gradeTotal,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<int>(subjectId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['due_date'] = Variable<DateTime>(dueDate);
    map['priority'] = Variable<int>(priority);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || gradeEarned != null) {
      map['grade_earned'] = Variable<double>(gradeEarned);
    }
    if (!nullToAbsent || gradeTotal != null) {
      map['grade_total'] = Variable<double>(gradeTotal);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AssignmentsCompanion toCompanion(bool nullToAbsent) {
    return AssignmentsCompanion(
      id: Value(id),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      dueDate: Value(dueDate),
      priority: Value(priority),
      completed: Value(completed),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      gradeEarned: gradeEarned == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeEarned),
      gradeTotal: gradeTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeTotal),
      createdAt: Value(createdAt),
    );
  }

  factory Assignment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Assignment(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int?>(json['subjectId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      priority: serializer.fromJson<int>(json['priority']),
      completed: serializer.fromJson<bool>(json['completed']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      gradeEarned: serializer.fromJson<double?>(json['gradeEarned']),
      gradeTotal: serializer.fromJson<double?>(json['gradeTotal']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int?>(subjectId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'priority': serializer.toJson<int>(priority),
      'completed': serializer.toJson<bool>(completed),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'gradeEarned': serializer.toJson<double?>(gradeEarned),
      'gradeTotal': serializer.toJson<double?>(gradeTotal),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Assignment copyWith({
    int? id,
    Value<int?> subjectId = const Value.absent(),
    String? title,
    Value<String?> notes = const Value.absent(),
    DateTime? dueDate,
    int? priority,
    bool? completed,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<double?> gradeEarned = const Value.absent(),
    Value<double?> gradeTotal = const Value.absent(),
    DateTime? createdAt,
  }) => Assignment(
    id: id ?? this.id,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    dueDate: dueDate ?? this.dueDate,
    priority: priority ?? this.priority,
    completed: completed ?? this.completed,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    gradeEarned: gradeEarned.present ? gradeEarned.value : this.gradeEarned,
    gradeTotal: gradeTotal.present ? gradeTotal.value : this.gradeTotal,
    createdAt: createdAt ?? this.createdAt,
  );
  Assignment copyWithCompanion(AssignmentsCompanion data) {
    return Assignment(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      priority: data.priority.present ? data.priority.value : this.priority,
      completed: data.completed.present ? data.completed.value : this.completed,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      gradeEarned: data.gradeEarned.present
          ? data.gradeEarned.value
          : this.gradeEarned,
      gradeTotal: data.gradeTotal.present
          ? data.gradeTotal.value
          : this.gradeTotal,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Assignment(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('dueDate: $dueDate, ')
          ..write('priority: $priority, ')
          ..write('completed: $completed, ')
          ..write('completedAt: $completedAt, ')
          ..write('gradeEarned: $gradeEarned, ')
          ..write('gradeTotal: $gradeTotal, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectId,
    title,
    notes,
    dueDate,
    priority,
    completed,
    completedAt,
    gradeEarned,
    gradeTotal,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Assignment &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.dueDate == this.dueDate &&
          other.priority == this.priority &&
          other.completed == this.completed &&
          other.completedAt == this.completedAt &&
          other.gradeEarned == this.gradeEarned &&
          other.gradeTotal == this.gradeTotal &&
          other.createdAt == this.createdAt);
}

class AssignmentsCompanion extends UpdateCompanion<Assignment> {
  final Value<int> id;
  final Value<int?> subjectId;
  final Value<String> title;
  final Value<String?> notes;
  final Value<DateTime> dueDate;
  final Value<int> priority;
  final Value<bool> completed;
  final Value<DateTime?> completedAt;
  final Value<double?> gradeEarned;
  final Value<double?> gradeTotal;
  final Value<DateTime> createdAt;
  const AssignmentsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.priority = const Value.absent(),
    this.completed = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.gradeEarned = const Value.absent(),
    this.gradeTotal = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AssignmentsCompanion.insert({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    required String title,
    this.notes = const Value.absent(),
    required DateTime dueDate,
    this.priority = const Value.absent(),
    this.completed = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.gradeEarned = const Value.absent(),
    this.gradeTotal = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : title = Value(title),
       dueDate = Value(dueDate);
  static Insertable<Assignment> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<DateTime>? dueDate,
    Expression<int>? priority,
    Expression<bool>? completed,
    Expression<DateTime>? completedAt,
    Expression<double>? gradeEarned,
    Expression<double>? gradeTotal,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (dueDate != null) 'due_date': dueDate,
      if (priority != null) 'priority': priority,
      if (completed != null) 'completed': completed,
      if (completedAt != null) 'completed_at': completedAt,
      if (gradeEarned != null) 'grade_earned': gradeEarned,
      if (gradeTotal != null) 'grade_total': gradeTotal,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AssignmentsCompanion copyWith({
    Value<int>? id,
    Value<int?>? subjectId,
    Value<String>? title,
    Value<String?>? notes,
    Value<DateTime>? dueDate,
    Value<int>? priority,
    Value<bool>? completed,
    Value<DateTime?>? completedAt,
    Value<double?>? gradeEarned,
    Value<double?>? gradeTotal,
    Value<DateTime>? createdAt,
  }) {
    return AssignmentsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      gradeEarned: gradeEarned ?? this.gradeEarned,
      gradeTotal: gradeTotal ?? this.gradeTotal,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (gradeEarned.present) {
      map['grade_earned'] = Variable<double>(gradeEarned.value);
    }
    if (gradeTotal.present) {
      map['grade_total'] = Variable<double>(gradeTotal.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssignmentsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('dueDate: $dueDate, ')
          ..write('priority: $priority, ')
          ..write('completed: $completed, ')
          ..write('completedAt: $completedAt, ')
          ..write('gradeEarned: $gradeEarned, ')
          ..write('gradeTotal: $gradeTotal, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TimetableEntriesTable extends TimetableEntries
    with TableInfo<$TimetableEntriesTable, TimetableEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimetableEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES school_subjects (id)',
    ),
  );
  static const VerificationMeta _dayOfWeekMeta = const VerificationMeta(
    'dayOfWeek',
  );
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
    'day_of_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinutesMeta = const VerificationMeta(
    'startMinutes',
  );
  @override
  late final GeneratedColumn<int> startMinutes = GeneratedColumn<int>(
    'start_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinutesMeta = const VerificationMeta(
    'endMinutes',
  );
  @override
  late final GeneratedColumn<int> endMinutes = GeneratedColumn<int>(
    'end_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _instructorMeta = const VerificationMeta(
    'instructor',
  );
  @override
  late final GeneratedColumn<String> instructor = GeneratedColumn<String>(
    'instructor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    dayOfWeek,
    startMinutes,
    endMinutes,
    location,
    instructor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timetable_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimetableEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
        _dayOfWeekMeta,
        dayOfWeek.isAcceptableOrUnknown(data['day_of_week']!, _dayOfWeekMeta),
      );
    } else if (isInserting) {
      context.missing(_dayOfWeekMeta);
    }
    if (data.containsKey('start_minutes')) {
      context.handle(
        _startMinutesMeta,
        startMinutes.isAcceptableOrUnknown(
          data['start_minutes']!,
          _startMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinutesMeta);
    }
    if (data.containsKey('end_minutes')) {
      context.handle(
        _endMinutesMeta,
        endMinutes.isAcceptableOrUnknown(data['end_minutes']!, _endMinutesMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinutesMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('instructor')) {
      context.handle(
        _instructorMeta,
        instructor.isAcceptableOrUnknown(data['instructor']!, _instructorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimetableEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimetableEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      dayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_week'],
      )!,
      startMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minutes'],
      )!,
      endMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minutes'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      instructor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instructor'],
      ),
    );
  }

  @override
  $TimetableEntriesTable createAlias(String alias) {
    return $TimetableEntriesTable(attachedDatabase, alias);
  }
}

class TimetableEntry extends DataClass implements Insertable<TimetableEntry> {
  final int id;
  final int subjectId;
  final int dayOfWeek;
  final int startMinutes;
  final int endMinutes;
  final String? location;
  final String? instructor;
  const TimetableEntry({
    required this.id,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    this.location,
    this.instructor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['day_of_week'] = Variable<int>(dayOfWeek);
    map['start_minutes'] = Variable<int>(startMinutes);
    map['end_minutes'] = Variable<int>(endMinutes);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || instructor != null) {
      map['instructor'] = Variable<String>(instructor);
    }
    return map;
  }

  TimetableEntriesCompanion toCompanion(bool nullToAbsent) {
    return TimetableEntriesCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      dayOfWeek: Value(dayOfWeek),
      startMinutes: Value(startMinutes),
      endMinutes: Value(endMinutes),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      instructor: instructor == null && nullToAbsent
          ? const Value.absent()
          : Value(instructor),
    );
  }

  factory TimetableEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimetableEntry(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      dayOfWeek: serializer.fromJson<int>(json['dayOfWeek']),
      startMinutes: serializer.fromJson<int>(json['startMinutes']),
      endMinutes: serializer.fromJson<int>(json['endMinutes']),
      location: serializer.fromJson<String?>(json['location']),
      instructor: serializer.fromJson<String?>(json['instructor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'dayOfWeek': serializer.toJson<int>(dayOfWeek),
      'startMinutes': serializer.toJson<int>(startMinutes),
      'endMinutes': serializer.toJson<int>(endMinutes),
      'location': serializer.toJson<String?>(location),
      'instructor': serializer.toJson<String?>(instructor),
    };
  }

  TimetableEntry copyWith({
    int? id,
    int? subjectId,
    int? dayOfWeek,
    int? startMinutes,
    int? endMinutes,
    Value<String?> location = const Value.absent(),
    Value<String?> instructor = const Value.absent(),
  }) => TimetableEntry(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    startMinutes: startMinutes ?? this.startMinutes,
    endMinutes: endMinutes ?? this.endMinutes,
    location: location.present ? location.value : this.location,
    instructor: instructor.present ? instructor.value : this.instructor,
  );
  TimetableEntry copyWithCompanion(TimetableEntriesCompanion data) {
    return TimetableEntry(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      startMinutes: data.startMinutes.present
          ? data.startMinutes.value
          : this.startMinutes,
      endMinutes: data.endMinutes.present
          ? data.endMinutes.value
          : this.endMinutes,
      location: data.location.present ? data.location.value : this.location,
      instructor: data.instructor.present
          ? data.instructor.value
          : this.instructor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimetableEntry(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('startMinutes: $startMinutes, ')
          ..write('endMinutes: $endMinutes, ')
          ..write('location: $location, ')
          ..write('instructor: $instructor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectId,
    dayOfWeek,
    startMinutes,
    endMinutes,
    location,
    instructor,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimetableEntry &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.dayOfWeek == this.dayOfWeek &&
          other.startMinutes == this.startMinutes &&
          other.endMinutes == this.endMinutes &&
          other.location == this.location &&
          other.instructor == this.instructor);
}

class TimetableEntriesCompanion extends UpdateCompanion<TimetableEntry> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<int> dayOfWeek;
  final Value<int> startMinutes;
  final Value<int> endMinutes;
  final Value<String?> location;
  final Value<String?> instructor;
  const TimetableEntriesCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.startMinutes = const Value.absent(),
    this.endMinutes = const Value.absent(),
    this.location = const Value.absent(),
    this.instructor = const Value.absent(),
  });
  TimetableEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required int dayOfWeek,
    required int startMinutes,
    required int endMinutes,
    this.location = const Value.absent(),
    this.instructor = const Value.absent(),
  }) : subjectId = Value(subjectId),
       dayOfWeek = Value(dayOfWeek),
       startMinutes = Value(startMinutes),
       endMinutes = Value(endMinutes);
  static Insertable<TimetableEntry> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<int>? dayOfWeek,
    Expression<int>? startMinutes,
    Expression<int>? endMinutes,
    Expression<String>? location,
    Expression<String>? instructor,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (startMinutes != null) 'start_minutes': startMinutes,
      if (endMinutes != null) 'end_minutes': endMinutes,
      if (location != null) 'location': location,
      if (instructor != null) 'instructor': instructor,
    });
  }

  TimetableEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<int>? dayOfWeek,
    Value<int>? startMinutes,
    Value<int>? endMinutes,
    Value<String?>? location,
    Value<String?>? instructor,
  }) {
    return TimetableEntriesCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      location: location ?? this.location,
      instructor: instructor ?? this.instructor,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (startMinutes.present) {
      map['start_minutes'] = Variable<int>(startMinutes.value);
    }
    if (endMinutes.present) {
      map['end_minutes'] = Variable<int>(endMinutes.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (instructor.present) {
      map['instructor'] = Variable<String>(instructor.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimetableEntriesCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('startMinutes: $startMinutes, ')
          ..write('endMinutes: $endMinutes, ')
          ..write('location: $location, ')
          ..write('instructor: $instructor')
          ..write(')'))
        .toString();
  }
}

class $FlashcardDecksTable extends FlashcardDecks
    with TableInfo<$FlashcardDecksTable, FlashcardDeck> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlashcardDecksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES school_subjects (id)',
    ),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, subjectId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flashcard_decks';
  @override
  VerificationContext validateIntegrity(
    Insertable<FlashcardDeck> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FlashcardDeck map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlashcardDeck(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FlashcardDecksTable createAlias(String alias) {
    return $FlashcardDecksTable(attachedDatabase, alias);
  }
}

class FlashcardDeck extends DataClass implements Insertable<FlashcardDeck> {
  final int id;
  final String name;
  final int? subjectId;
  final DateTime createdAt;
  const FlashcardDeck({
    required this.id,
    required this.name,
    this.subjectId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<int>(subjectId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FlashcardDecksCompanion toCompanion(bool nullToAbsent) {
    return FlashcardDecksCompanion(
      id: Value(id),
      name: Value(name),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      createdAt: Value(createdAt),
    );
  }

  factory FlashcardDeck.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FlashcardDeck(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      subjectId: serializer.fromJson<int?>(json['subjectId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'subjectId': serializer.toJson<int?>(subjectId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FlashcardDeck copyWith({
    int? id,
    String? name,
    Value<int?> subjectId = const Value.absent(),
    DateTime? createdAt,
  }) => FlashcardDeck(
    id: id ?? this.id,
    name: name ?? this.name,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    createdAt: createdAt ?? this.createdAt,
  );
  FlashcardDeck copyWithCompanion(FlashcardDecksCompanion data) {
    return FlashcardDeck(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardDeck(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('subjectId: $subjectId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, subjectId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlashcardDeck &&
          other.id == this.id &&
          other.name == this.name &&
          other.subjectId == this.subjectId &&
          other.createdAt == this.createdAt);
}

class FlashcardDecksCompanion extends UpdateCompanion<FlashcardDeck> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> subjectId;
  final Value<DateTime> createdAt;
  const FlashcardDecksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FlashcardDecksCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.subjectId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<FlashcardDeck> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? subjectId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (subjectId != null) 'subject_id': subjectId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FlashcardDecksCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? subjectId,
    Value<DateTime>? createdAt,
  }) {
    return FlashcardDecksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      subjectId: subjectId ?? this.subjectId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardDecksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('subjectId: $subjectId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FlashcardsTable extends Flashcards
    with TableInfo<$FlashcardsTable, Flashcard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlashcardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<int> deckId = GeneratedColumn<int>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES flashcard_decks (id)',
    ),
  );
  static const VerificationMeta _frontMeta = const VerificationMeta('front');
  @override
  late final GeneratedColumn<String> front = GeneratedColumn<String>(
    'front',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backMeta = const VerificationMeta('back');
  @override
  late final GeneratedColumn<String> back = GeneratedColumn<String>(
    'back',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _easeFactorMeta = const VerificationMeta(
    'easeFactor',
  );
  @override
  late final GeneratedColumn<double> easeFactor = GeneratedColumn<double>(
    'ease_factor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repetitionsMeta = const VerificationMeta(
    'repetitions',
  );
  @override
  late final GeneratedColumn<int> repetitions = GeneratedColumn<int>(
    'repetitions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextReviewDateMeta = const VerificationMeta(
    'nextReviewDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextReviewDate =
      GeneratedColumn<DateTime>(
        'next_review_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _lastReviewedAtMeta = const VerificationMeta(
    'lastReviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReviewedAt =
      GeneratedColumn<DateTime>(
        'last_reviewed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deckId,
    front,
    back,
    easeFactor,
    intervalDays,
    repetitions,
    nextReviewDate,
    lastReviewedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flashcards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Flashcard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('front')) {
      context.handle(
        _frontMeta,
        front.isAcceptableOrUnknown(data['front']!, _frontMeta),
      );
    } else if (isInserting) {
      context.missing(_frontMeta);
    }
    if (data.containsKey('back')) {
      context.handle(
        _backMeta,
        back.isAcceptableOrUnknown(data['back']!, _backMeta),
      );
    } else if (isInserting) {
      context.missing(_backMeta);
    }
    if (data.containsKey('ease_factor')) {
      context.handle(
        _easeFactorMeta,
        easeFactor.isAcceptableOrUnknown(data['ease_factor']!, _easeFactorMeta),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('repetitions')) {
      context.handle(
        _repetitionsMeta,
        repetitions.isAcceptableOrUnknown(
          data['repetitions']!,
          _repetitionsMeta,
        ),
      );
    }
    if (data.containsKey('next_review_date')) {
      context.handle(
        _nextReviewDateMeta,
        nextReviewDate.isAcceptableOrUnknown(
          data['next_review_date']!,
          _nextReviewDateMeta,
        ),
      );
    }
    if (data.containsKey('last_reviewed_at')) {
      context.handle(
        _lastReviewedAtMeta,
        lastReviewedAt.isAcceptableOrUnknown(
          data['last_reviewed_at']!,
          _lastReviewedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Flashcard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Flashcard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deck_id'],
      )!,
      front: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front'],
      )!,
      back: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}back'],
      )!,
      easeFactor: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease_factor'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      repetitions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetitions'],
      )!,
      nextReviewDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_review_date'],
      )!,
      lastReviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reviewed_at'],
      ),
    );
  }

  @override
  $FlashcardsTable createAlias(String alias) {
    return $FlashcardsTable(attachedDatabase, alias);
  }
}

class Flashcard extends DataClass implements Insertable<Flashcard> {
  final int id;
  final int deckId;
  final String front;
  final String back;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime nextReviewDate;
  final DateTime? lastReviewedAt;
  const Flashcard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.nextReviewDate,
    this.lastReviewedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['deck_id'] = Variable<int>(deckId);
    map['front'] = Variable<String>(front);
    map['back'] = Variable<String>(back);
    map['ease_factor'] = Variable<double>(easeFactor);
    map['interval_days'] = Variable<int>(intervalDays);
    map['repetitions'] = Variable<int>(repetitions);
    map['next_review_date'] = Variable<DateTime>(nextReviewDate);
    if (!nullToAbsent || lastReviewedAt != null) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt);
    }
    return map;
  }

  FlashcardsCompanion toCompanion(bool nullToAbsent) {
    return FlashcardsCompanion(
      id: Value(id),
      deckId: Value(deckId),
      front: Value(front),
      back: Value(back),
      easeFactor: Value(easeFactor),
      intervalDays: Value(intervalDays),
      repetitions: Value(repetitions),
      nextReviewDate: Value(nextReviewDate),
      lastReviewedAt: lastReviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewedAt),
    );
  }

  factory Flashcard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Flashcard(
      id: serializer.fromJson<int>(json['id']),
      deckId: serializer.fromJson<int>(json['deckId']),
      front: serializer.fromJson<String>(json['front']),
      back: serializer.fromJson<String>(json['back']),
      easeFactor: serializer.fromJson<double>(json['easeFactor']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      repetitions: serializer.fromJson<int>(json['repetitions']),
      nextReviewDate: serializer.fromJson<DateTime>(json['nextReviewDate']),
      lastReviewedAt: serializer.fromJson<DateTime?>(json['lastReviewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deckId': serializer.toJson<int>(deckId),
      'front': serializer.toJson<String>(front),
      'back': serializer.toJson<String>(back),
      'easeFactor': serializer.toJson<double>(easeFactor),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'repetitions': serializer.toJson<int>(repetitions),
      'nextReviewDate': serializer.toJson<DateTime>(nextReviewDate),
      'lastReviewedAt': serializer.toJson<DateTime?>(lastReviewedAt),
    };
  }

  Flashcard copyWith({
    int? id,
    int? deckId,
    String? front,
    String? back,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    DateTime? nextReviewDate,
    Value<DateTime?> lastReviewedAt = const Value.absent(),
  }) => Flashcard(
    id: id ?? this.id,
    deckId: deckId ?? this.deckId,
    front: front ?? this.front,
    back: back ?? this.back,
    easeFactor: easeFactor ?? this.easeFactor,
    intervalDays: intervalDays ?? this.intervalDays,
    repetitions: repetitions ?? this.repetitions,
    nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    lastReviewedAt: lastReviewedAt.present
        ? lastReviewedAt.value
        : this.lastReviewedAt,
  );
  Flashcard copyWithCompanion(FlashcardsCompanion data) {
    return Flashcard(
      id: data.id.present ? data.id.value : this.id,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      front: data.front.present ? data.front.value : this.front,
      back: data.back.present ? data.back.value : this.back,
      easeFactor: data.easeFactor.present
          ? data.easeFactor.value
          : this.easeFactor,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      repetitions: data.repetitions.present
          ? data.repetitions.value
          : this.repetitions,
      nextReviewDate: data.nextReviewDate.present
          ? data.nextReviewDate.value
          : this.nextReviewDate,
      lastReviewedAt: data.lastReviewedAt.present
          ? data.lastReviewedAt.value
          : this.lastReviewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Flashcard(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('repetitions: $repetitions, ')
          ..write('nextReviewDate: $nextReviewDate, ')
          ..write('lastReviewedAt: $lastReviewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deckId,
    front,
    back,
    easeFactor,
    intervalDays,
    repetitions,
    nextReviewDate,
    lastReviewedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Flashcard &&
          other.id == this.id &&
          other.deckId == this.deckId &&
          other.front == this.front &&
          other.back == this.back &&
          other.easeFactor == this.easeFactor &&
          other.intervalDays == this.intervalDays &&
          other.repetitions == this.repetitions &&
          other.nextReviewDate == this.nextReviewDate &&
          other.lastReviewedAt == this.lastReviewedAt);
}

class FlashcardsCompanion extends UpdateCompanion<Flashcard> {
  final Value<int> id;
  final Value<int> deckId;
  final Value<String> front;
  final Value<String> back;
  final Value<double> easeFactor;
  final Value<int> intervalDays;
  final Value<int> repetitions;
  final Value<DateTime> nextReviewDate;
  final Value<DateTime?> lastReviewedAt;
  const FlashcardsCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.front = const Value.absent(),
    this.back = const Value.absent(),
    this.easeFactor = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.repetitions = const Value.absent(),
    this.nextReviewDate = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
  });
  FlashcardsCompanion.insert({
    this.id = const Value.absent(),
    required int deckId,
    required String front,
    required String back,
    this.easeFactor = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.repetitions = const Value.absent(),
    this.nextReviewDate = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
  }) : deckId = Value(deckId),
       front = Value(front),
       back = Value(back);
  static Insertable<Flashcard> custom({
    Expression<int>? id,
    Expression<int>? deckId,
    Expression<String>? front,
    Expression<String>? back,
    Expression<double>? easeFactor,
    Expression<int>? intervalDays,
    Expression<int>? repetitions,
    Expression<DateTime>? nextReviewDate,
    Expression<DateTime>? lastReviewedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (front != null) 'front': front,
      if (back != null) 'back': back,
      if (easeFactor != null) 'ease_factor': easeFactor,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (repetitions != null) 'repetitions': repetitions,
      if (nextReviewDate != null) 'next_review_date': nextReviewDate,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
    });
  }

  FlashcardsCompanion copyWith({
    Value<int>? id,
    Value<int>? deckId,
    Value<String>? front,
    Value<String>? back,
    Value<double>? easeFactor,
    Value<int>? intervalDays,
    Value<int>? repetitions,
    Value<DateTime>? nextReviewDate,
    Value<DateTime?>? lastReviewedAt,
  }) {
    return FlashcardsCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<int>(deckId.value);
    }
    if (front.present) {
      map['front'] = Variable<String>(front.value);
    }
    if (back.present) {
      map['back'] = Variable<String>(back.value);
    }
    if (easeFactor.present) {
      map['ease_factor'] = Variable<double>(easeFactor.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (repetitions.present) {
      map['repetitions'] = Variable<int>(repetitions.value);
    }
    if (nextReviewDate.present) {
      map['next_review_date'] = Variable<DateTime>(nextReviewDate.value);
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardsCompanion(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('repetitions: $repetitions, ')
          ..write('nextReviewDate: $nextReviewDate, ')
          ..write('lastReviewedAt: $lastReviewedAt')
          ..write(')'))
        .toString();
  }
}

class $FormulasTable extends Formulas with TableInfo<$FormulasTable, Formula> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FormulasTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Custom'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 150,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expressionMeta = const VerificationMeta(
    'expression',
  );
  @override
  late final GeneratedColumn<String> expression = GeneratedColumn<String>(
    'expression',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    name,
    expression,
    description,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'formulas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Formula> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('expression')) {
      context.handle(
        _expressionMeta,
        expression.isAcceptableOrUnknown(data['expression']!, _expressionMeta),
      );
    } else if (isInserting) {
      context.missing(_expressionMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Formula map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Formula(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      expression: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expression'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FormulasTable createAlias(String alias) {
    return $FormulasTable(attachedDatabase, alias);
  }
}

class Formula extends DataClass implements Insertable<Formula> {
  final int id;
  final String category;
  final String name;
  final String expression;
  final String? description;
  final DateTime createdAt;
  const Formula({
    required this.id,
    required this.category,
    required this.name,
    required this.expression,
    this.description,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category'] = Variable<String>(category);
    map['name'] = Variable<String>(name);
    map['expression'] = Variable<String>(expression);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FormulasCompanion toCompanion(bool nullToAbsent) {
    return FormulasCompanion(
      id: Value(id),
      category: Value(category),
      name: Value(name),
      expression: Value(expression),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
    );
  }

  factory Formula.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Formula(
      id: serializer.fromJson<int>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      name: serializer.fromJson<String>(json['name']),
      expression: serializer.fromJson<String>(json['expression']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'category': serializer.toJson<String>(category),
      'name': serializer.toJson<String>(name),
      'expression': serializer.toJson<String>(expression),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Formula copyWith({
    int? id,
    String? category,
    String? name,
    String? expression,
    Value<String?> description = const Value.absent(),
    DateTime? createdAt,
  }) => Formula(
    id: id ?? this.id,
    category: category ?? this.category,
    name: name ?? this.name,
    expression: expression ?? this.expression,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
  );
  Formula copyWithCompanion(FormulasCompanion data) {
    return Formula(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      name: data.name.present ? data.name.value : this.name,
      expression: data.expression.present
          ? data.expression.value
          : this.expression,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Formula(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('name: $name, ')
          ..write('expression: $expression, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, category, name, expression, description, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Formula &&
          other.id == this.id &&
          other.category == this.category &&
          other.name == this.name &&
          other.expression == this.expression &&
          other.description == this.description &&
          other.createdAt == this.createdAt);
}

class FormulasCompanion extends UpdateCompanion<Formula> {
  final Value<int> id;
  final Value<String> category;
  final Value<String> name;
  final Value<String> expression;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  const FormulasCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.name = const Value.absent(),
    this.expression = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FormulasCompanion.insert({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    required String name,
    required String expression,
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       expression = Value(expression);
  static Insertable<Formula> custom({
    Expression<int>? id,
    Expression<String>? category,
    Expression<String>? name,
    Expression<String>? expression,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (name != null) 'name': name,
      if (expression != null) 'expression': expression,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FormulasCompanion copyWith({
    Value<int>? id,
    Value<String>? category,
    Value<String>? name,
    Value<String>? expression,
    Value<String?>? description,
    Value<DateTime>? createdAt,
  }) {
    return FormulasCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      expression: expression ?? this.expression,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (expression.present) {
      map['expression'] = Variable<String>(expression.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FormulasCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('name: $name, ')
          ..write('expression: $expression, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GradeComponentsTable extends GradeComponents
    with TableInfo<$GradeComponentsTable, GradeComponent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GradeComponentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES school_subjects (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightPercentMeta = const VerificationMeta(
    'weightPercent',
  );
  @override
  late final GeneratedColumn<double> weightPercent = GeneratedColumn<double>(
    'weight_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreEarnedMeta = const VerificationMeta(
    'scoreEarned',
  );
  @override
  late final GeneratedColumn<double> scoreEarned = GeneratedColumn<double>(
    'score_earned',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreTotalMeta = const VerificationMeta(
    'scoreTotal',
  );
  @override
  late final GeneratedColumn<double> scoreTotal = GeneratedColumn<double>(
    'score_total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    name,
    weightPercent,
    scoreEarned,
    scoreTotal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'grade_components';
  @override
  VerificationContext validateIntegrity(
    Insertable<GradeComponent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('weight_percent')) {
      context.handle(
        _weightPercentMeta,
        weightPercent.isAcceptableOrUnknown(
          data['weight_percent']!,
          _weightPercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_weightPercentMeta);
    }
    if (data.containsKey('score_earned')) {
      context.handle(
        _scoreEarnedMeta,
        scoreEarned.isAcceptableOrUnknown(
          data['score_earned']!,
          _scoreEarnedMeta,
        ),
      );
    }
    if (data.containsKey('score_total')) {
      context.handle(
        _scoreTotalMeta,
        scoreTotal.isAcceptableOrUnknown(data['score_total']!, _scoreTotalMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GradeComponent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GradeComponent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      weightPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_percent'],
      )!,
      scoreEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score_earned'],
      ),
      scoreTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score_total'],
      )!,
    );
  }

  @override
  $GradeComponentsTable createAlias(String alias) {
    return $GradeComponentsTable(attachedDatabase, alias);
  }
}

class GradeComponent extends DataClass implements Insertable<GradeComponent> {
  final int id;
  final int subjectId;
  final String name;
  final double weightPercent;
  final double? scoreEarned;
  final double scoreTotal;
  const GradeComponent({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.weightPercent,
    this.scoreEarned,
    required this.scoreTotal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['name'] = Variable<String>(name);
    map['weight_percent'] = Variable<double>(weightPercent);
    if (!nullToAbsent || scoreEarned != null) {
      map['score_earned'] = Variable<double>(scoreEarned);
    }
    map['score_total'] = Variable<double>(scoreTotal);
    return map;
  }

  GradeComponentsCompanion toCompanion(bool nullToAbsent) {
    return GradeComponentsCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      name: Value(name),
      weightPercent: Value(weightPercent),
      scoreEarned: scoreEarned == null && nullToAbsent
          ? const Value.absent()
          : Value(scoreEarned),
      scoreTotal: Value(scoreTotal),
    );
  }

  factory GradeComponent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GradeComponent(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      name: serializer.fromJson<String>(json['name']),
      weightPercent: serializer.fromJson<double>(json['weightPercent']),
      scoreEarned: serializer.fromJson<double?>(json['scoreEarned']),
      scoreTotal: serializer.fromJson<double>(json['scoreTotal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'name': serializer.toJson<String>(name),
      'weightPercent': serializer.toJson<double>(weightPercent),
      'scoreEarned': serializer.toJson<double?>(scoreEarned),
      'scoreTotal': serializer.toJson<double>(scoreTotal),
    };
  }

  GradeComponent copyWith({
    int? id,
    int? subjectId,
    String? name,
    double? weightPercent,
    Value<double?> scoreEarned = const Value.absent(),
    double? scoreTotal,
  }) => GradeComponent(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    name: name ?? this.name,
    weightPercent: weightPercent ?? this.weightPercent,
    scoreEarned: scoreEarned.present ? scoreEarned.value : this.scoreEarned,
    scoreTotal: scoreTotal ?? this.scoreTotal,
  );
  GradeComponent copyWithCompanion(GradeComponentsCompanion data) {
    return GradeComponent(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      name: data.name.present ? data.name.value : this.name,
      weightPercent: data.weightPercent.present
          ? data.weightPercent.value
          : this.weightPercent,
      scoreEarned: data.scoreEarned.present
          ? data.scoreEarned.value
          : this.scoreEarned,
      scoreTotal: data.scoreTotal.present
          ? data.scoreTotal.value
          : this.scoreTotal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GradeComponent(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('name: $name, ')
          ..write('weightPercent: $weightPercent, ')
          ..write('scoreEarned: $scoreEarned, ')
          ..write('scoreTotal: $scoreTotal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectId, name, weightPercent, scoreEarned, scoreTotal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GradeComponent &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.name == this.name &&
          other.weightPercent == this.weightPercent &&
          other.scoreEarned == this.scoreEarned &&
          other.scoreTotal == this.scoreTotal);
}

class GradeComponentsCompanion extends UpdateCompanion<GradeComponent> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<String> name;
  final Value<double> weightPercent;
  final Value<double?> scoreEarned;
  final Value<double> scoreTotal;
  const GradeComponentsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.name = const Value.absent(),
    this.weightPercent = const Value.absent(),
    this.scoreEarned = const Value.absent(),
    this.scoreTotal = const Value.absent(),
  });
  GradeComponentsCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required String name,
    required double weightPercent,
    this.scoreEarned = const Value.absent(),
    this.scoreTotal = const Value.absent(),
  }) : subjectId = Value(subjectId),
       name = Value(name),
       weightPercent = Value(weightPercent);
  static Insertable<GradeComponent> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<String>? name,
    Expression<double>? weightPercent,
    Expression<double>? scoreEarned,
    Expression<double>? scoreTotal,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (name != null) 'name': name,
      if (weightPercent != null) 'weight_percent': weightPercent,
      if (scoreEarned != null) 'score_earned': scoreEarned,
      if (scoreTotal != null) 'score_total': scoreTotal,
    });
  }

  GradeComponentsCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<String>? name,
    Value<double>? weightPercent,
    Value<double?>? scoreEarned,
    Value<double>? scoreTotal,
  }) {
    return GradeComponentsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      weightPercent: weightPercent ?? this.weightPercent,
      scoreEarned: scoreEarned ?? this.scoreEarned,
      scoreTotal: scoreTotal ?? this.scoreTotal,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (weightPercent.present) {
      map['weight_percent'] = Variable<double>(weightPercent.value);
    }
    if (scoreEarned.present) {
      map['score_earned'] = Variable<double>(scoreEarned.value);
    }
    if (scoreTotal.present) {
      map['score_total'] = Variable<double>(scoreTotal.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GradeComponentsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('name: $name, ')
          ..write('weightPercent: $weightPercent, ')
          ..write('scoreEarned: $scoreEarned, ')
          ..write('scoreTotal: $scoreTotal')
          ..write(')'))
        .toString();
  }
}

class $GpaRecordsTable extends GpaRecords
    with TableInfo<$GpaRecordsTable, GpaRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GpaRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES school_subjects (id)',
    ),
  );
  static const VerificationMeta _termNameMeta = const VerificationMeta(
    'termName',
  );
  @override
  late final GeneratedColumn<String> termName = GeneratedColumn<String>(
    'term_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditHoursMeta = const VerificationMeta(
    'creditHours',
  );
  @override
  late final GeneratedColumn<double> creditHours = GeneratedColumn<double>(
    'credit_hours',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gradePointsMeta = const VerificationMeta(
    'gradePoints',
  );
  @override
  late final GeneratedColumn<double> gradePoints = GeneratedColumn<double>(
    'grade_points',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    termName,
    creditHours,
    gradePoints,
    date,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gpa_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<GpaRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('term_name')) {
      context.handle(
        _termNameMeta,
        termName.isAcceptableOrUnknown(data['term_name']!, _termNameMeta),
      );
    } else if (isInserting) {
      context.missing(_termNameMeta);
    }
    if (data.containsKey('credit_hours')) {
      context.handle(
        _creditHoursMeta,
        creditHours.isAcceptableOrUnknown(
          data['credit_hours']!,
          _creditHoursMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creditHoursMeta);
    }
    if (data.containsKey('grade_points')) {
      context.handle(
        _gradePointsMeta,
        gradePoints.isAcceptableOrUnknown(
          data['grade_points']!,
          _gradePointsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_gradePointsMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GpaRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GpaRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      termName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}term_name'],
      )!,
      creditHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}credit_hours'],
      )!,
      gradePoints: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grade_points'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
    );
  }

  @override
  $GpaRecordsTable createAlias(String alias) {
    return $GpaRecordsTable(attachedDatabase, alias);
  }
}

class GpaRecord extends DataClass implements Insertable<GpaRecord> {
  final int id;
  final int subjectId;
  final String termName;
  final double creditHours;
  final double gradePoints;
  final DateTime date;
  const GpaRecord({
    required this.id,
    required this.subjectId,
    required this.termName,
    required this.creditHours,
    required this.gradePoints,
    required this.date,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['term_name'] = Variable<String>(termName);
    map['credit_hours'] = Variable<double>(creditHours);
    map['grade_points'] = Variable<double>(gradePoints);
    map['date'] = Variable<DateTime>(date);
    return map;
  }

  GpaRecordsCompanion toCompanion(bool nullToAbsent) {
    return GpaRecordsCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      termName: Value(termName),
      creditHours: Value(creditHours),
      gradePoints: Value(gradePoints),
      date: Value(date),
    );
  }

  factory GpaRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GpaRecord(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      termName: serializer.fromJson<String>(json['termName']),
      creditHours: serializer.fromJson<double>(json['creditHours']),
      gradePoints: serializer.fromJson<double>(json['gradePoints']),
      date: serializer.fromJson<DateTime>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'termName': serializer.toJson<String>(termName),
      'creditHours': serializer.toJson<double>(creditHours),
      'gradePoints': serializer.toJson<double>(gradePoints),
      'date': serializer.toJson<DateTime>(date),
    };
  }

  GpaRecord copyWith({
    int? id,
    int? subjectId,
    String? termName,
    double? creditHours,
    double? gradePoints,
    DateTime? date,
  }) => GpaRecord(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    termName: termName ?? this.termName,
    creditHours: creditHours ?? this.creditHours,
    gradePoints: gradePoints ?? this.gradePoints,
    date: date ?? this.date,
  );
  GpaRecord copyWithCompanion(GpaRecordsCompanion data) {
    return GpaRecord(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      termName: data.termName.present ? data.termName.value : this.termName,
      creditHours: data.creditHours.present
          ? data.creditHours.value
          : this.creditHours,
      gradePoints: data.gradePoints.present
          ? data.gradePoints.value
          : this.gradePoints,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GpaRecord(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('termName: $termName, ')
          ..write('creditHours: $creditHours, ')
          ..write('gradePoints: $gradePoints, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectId, termName, creditHours, gradePoints, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GpaRecord &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.termName == this.termName &&
          other.creditHours == this.creditHours &&
          other.gradePoints == this.gradePoints &&
          other.date == this.date);
}

class GpaRecordsCompanion extends UpdateCompanion<GpaRecord> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<String> termName;
  final Value<double> creditHours;
  final Value<double> gradePoints;
  final Value<DateTime> date;
  const GpaRecordsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.termName = const Value.absent(),
    this.creditHours = const Value.absent(),
    this.gradePoints = const Value.absent(),
    this.date = const Value.absent(),
  });
  GpaRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required String termName,
    required double creditHours,
    required double gradePoints,
    this.date = const Value.absent(),
  }) : subjectId = Value(subjectId),
       termName = Value(termName),
       creditHours = Value(creditHours),
       gradePoints = Value(gradePoints);
  static Insertable<GpaRecord> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<String>? termName,
    Expression<double>? creditHours,
    Expression<double>? gradePoints,
    Expression<DateTime>? date,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (termName != null) 'term_name': termName,
      if (creditHours != null) 'credit_hours': creditHours,
      if (gradePoints != null) 'grade_points': gradePoints,
      if (date != null) 'date': date,
    });
  }

  GpaRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<String>? termName,
    Value<double>? creditHours,
    Value<double>? gradePoints,
    Value<DateTime>? date,
  }) {
    return GpaRecordsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      termName: termName ?? this.termName,
      creditHours: creditHours ?? this.creditHours,
      gradePoints: gradePoints ?? this.gradePoints,
      date: date ?? this.date,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (termName.present) {
      map['term_name'] = Variable<String>(termName.value);
    }
    if (creditHours.present) {
      map['credit_hours'] = Variable<double>(creditHours.value);
    }
    if (gradePoints.present) {
      map['grade_points'] = Variable<double>(gradePoints.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GpaRecordsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('termName: $termName, ')
          ..write('creditHours: $creditHours, ')
          ..write('gradePoints: $gradePoints, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }
}

class $CitationsTable extends Citations
    with TableInfo<$CitationsTable, Citation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CitationsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
    'style',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldsJsonMeta = const VerificationMeta(
    'fieldsJson',
  );
  @override
  late final GeneratedColumn<String> fieldsJson = GeneratedColumn<String>(
    'fields_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _formattedTextMeta = const VerificationMeta(
    'formattedText',
  );
  @override
  late final GeneratedColumn<String> formattedText = GeneratedColumn<String>(
    'formatted_text',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    style,
    sourceType,
    fieldsJson,
    formattedText,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'citations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Citation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('style')) {
      context.handle(
        _styleMeta,
        style.isAcceptableOrUnknown(data['style']!, _styleMeta),
      );
    } else if (isInserting) {
      context.missing(_styleMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('fields_json')) {
      context.handle(
        _fieldsJsonMeta,
        fieldsJson.isAcceptableOrUnknown(data['fields_json']!, _fieldsJsonMeta),
      );
    }
    if (data.containsKey('formatted_text')) {
      context.handle(
        _formattedTextMeta,
        formattedText.isAcceptableOrUnknown(
          data['formatted_text']!,
          _formattedTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formattedTextMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Citation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Citation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      style: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      fieldsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fields_json'],
      )!,
      formattedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}formatted_text'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CitationsTable createAlias(String alias) {
    return $CitationsTable(attachedDatabase, alias);
  }
}

class Citation extends DataClass implements Insertable<Citation> {
  final int id;
  final String style;
  final String sourceType;
  final String fieldsJson;
  final String formattedText;
  final DateTime createdAt;
  const Citation({
    required this.id,
    required this.style,
    required this.sourceType,
    required this.fieldsJson,
    required this.formattedText,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['style'] = Variable<String>(style);
    map['source_type'] = Variable<String>(sourceType);
    map['fields_json'] = Variable<String>(fieldsJson);
    map['formatted_text'] = Variable<String>(formattedText);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CitationsCompanion toCompanion(bool nullToAbsent) {
    return CitationsCompanion(
      id: Value(id),
      style: Value(style),
      sourceType: Value(sourceType),
      fieldsJson: Value(fieldsJson),
      formattedText: Value(formattedText),
      createdAt: Value(createdAt),
    );
  }

  factory Citation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Citation(
      id: serializer.fromJson<int>(json['id']),
      style: serializer.fromJson<String>(json['style']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      fieldsJson: serializer.fromJson<String>(json['fieldsJson']),
      formattedText: serializer.fromJson<String>(json['formattedText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'style': serializer.toJson<String>(style),
      'sourceType': serializer.toJson<String>(sourceType),
      'fieldsJson': serializer.toJson<String>(fieldsJson),
      'formattedText': serializer.toJson<String>(formattedText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Citation copyWith({
    int? id,
    String? style,
    String? sourceType,
    String? fieldsJson,
    String? formattedText,
    DateTime? createdAt,
  }) => Citation(
    id: id ?? this.id,
    style: style ?? this.style,
    sourceType: sourceType ?? this.sourceType,
    fieldsJson: fieldsJson ?? this.fieldsJson,
    formattedText: formattedText ?? this.formattedText,
    createdAt: createdAt ?? this.createdAt,
  );
  Citation copyWithCompanion(CitationsCompanion data) {
    return Citation(
      id: data.id.present ? data.id.value : this.id,
      style: data.style.present ? data.style.value : this.style,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      fieldsJson: data.fieldsJson.present
          ? data.fieldsJson.value
          : this.fieldsJson,
      formattedText: data.formattedText.present
          ? data.formattedText.value
          : this.formattedText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Citation(')
          ..write('id: $id, ')
          ..write('style: $style, ')
          ..write('sourceType: $sourceType, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('formattedText: $formattedText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, style, sourceType, fieldsJson, formattedText, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Citation &&
          other.id == this.id &&
          other.style == this.style &&
          other.sourceType == this.sourceType &&
          other.fieldsJson == this.fieldsJson &&
          other.formattedText == this.formattedText &&
          other.createdAt == this.createdAt);
}

class CitationsCompanion extends UpdateCompanion<Citation> {
  final Value<int> id;
  final Value<String> style;
  final Value<String> sourceType;
  final Value<String> fieldsJson;
  final Value<String> formattedText;
  final Value<DateTime> createdAt;
  const CitationsCompanion({
    this.id = const Value.absent(),
    this.style = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.fieldsJson = const Value.absent(),
    this.formattedText = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CitationsCompanion.insert({
    this.id = const Value.absent(),
    required String style,
    required String sourceType,
    this.fieldsJson = const Value.absent(),
    required String formattedText,
    this.createdAt = const Value.absent(),
  }) : style = Value(style),
       sourceType = Value(sourceType),
       formattedText = Value(formattedText);
  static Insertable<Citation> custom({
    Expression<int>? id,
    Expression<String>? style,
    Expression<String>? sourceType,
    Expression<String>? fieldsJson,
    Expression<String>? formattedText,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (style != null) 'style': style,
      if (sourceType != null) 'source_type': sourceType,
      if (fieldsJson != null) 'fields_json': fieldsJson,
      if (formattedText != null) 'formatted_text': formattedText,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CitationsCompanion copyWith({
    Value<int>? id,
    Value<String>? style,
    Value<String>? sourceType,
    Value<String>? fieldsJson,
    Value<String>? formattedText,
    Value<DateTime>? createdAt,
  }) {
    return CitationsCompanion(
      id: id ?? this.id,
      style: style ?? this.style,
      sourceType: sourceType ?? this.sourceType,
      fieldsJson: fieldsJson ?? this.fieldsJson,
      formattedText: formattedText ?? this.formattedText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (fieldsJson.present) {
      map['fields_json'] = Variable<String>(fieldsJson.value);
    }
    if (formattedText.present) {
      map['formatted_text'] = Variable<String>(formattedText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CitationsCompanion(')
          ..write('id: $id, ')
          ..write('style: $style, ')
          ..write('sourceType: $sourceType, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('formattedText: $formattedText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MindMapsTable extends MindMaps with TableInfo<$MindMapsTable, MindMap> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MindMapsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mind_maps';
  @override
  VerificationContext validateIntegrity(
    Insertable<MindMap> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MindMap map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MindMap(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MindMapsTable createAlias(String alias) {
    return $MindMapsTable(attachedDatabase, alias);
  }
}

class MindMap extends DataClass implements Insertable<MindMap> {
  final int id;
  final String title;
  final DateTime updatedAt;
  const MindMap({
    required this.id,
    required this.title,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MindMapsCompanion toCompanion(bool nullToAbsent) {
    return MindMapsCompanion(
      id: Value(id),
      title: Value(title),
      updatedAt: Value(updatedAt),
    );
  }

  factory MindMap.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MindMap(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MindMap copyWith({int? id, String? title, DateTime? updatedAt}) => MindMap(
    id: id ?? this.id,
    title: title ?? this.title,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MindMap copyWithCompanion(MindMapsCompanion data) {
    return MindMap(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MindMap(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MindMap &&
          other.id == this.id &&
          other.title == this.title &&
          other.updatedAt == this.updatedAt);
}

class MindMapsCompanion extends UpdateCompanion<MindMap> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> updatedAt;
  const MindMapsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MindMapsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.updatedAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<MindMap> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MindMapsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<DateTime>? updatedAt,
  }) {
    return MindMapsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MindMapsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MindMapNodesTable extends MindMapNodes
    with TableInfo<$MindMapNodesTable, MindMapNode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MindMapNodesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _mapIdMeta = const VerificationMeta('mapId');
  @override
  late final GeneratedColumn<int> mapId = GeneratedColumn<int>(
    'map_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mind_maps (id)',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF7C5AD9),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mapId,
    label,
    x,
    y,
    color,
    parentId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mind_map_nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<MindMapNode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('map_id')) {
      context.handle(
        _mapIdMeta,
        mapId.isAcceptableOrUnknown(data['map_id']!, _mapIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mapIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MindMapNode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MindMapNode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mapId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}map_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
    );
  }

  @override
  $MindMapNodesTable createAlias(String alias) {
    return $MindMapNodesTable(attachedDatabase, alias);
  }
}

class MindMapNode extends DataClass implements Insertable<MindMapNode> {
  final int id;
  final int mapId;
  final String label;
  final double x;
  final double y;
  final int color;
  final int? parentId;
  const MindMapNode({
    required this.id,
    required this.mapId,
    required this.label,
    required this.x,
    required this.y,
    required this.color,
    this.parentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['map_id'] = Variable<int>(mapId);
    map['label'] = Variable<String>(label);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['color'] = Variable<int>(color);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    return map;
  }

  MindMapNodesCompanion toCompanion(bool nullToAbsent) {
    return MindMapNodesCompanion(
      id: Value(id),
      mapId: Value(mapId),
      label: Value(label),
      x: Value(x),
      y: Value(y),
      color: Value(color),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
    );
  }

  factory MindMapNode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MindMapNode(
      id: serializer.fromJson<int>(json['id']),
      mapId: serializer.fromJson<int>(json['mapId']),
      label: serializer.fromJson<String>(json['label']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      color: serializer.fromJson<int>(json['color']),
      parentId: serializer.fromJson<int?>(json['parentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mapId': serializer.toJson<int>(mapId),
      'label': serializer.toJson<String>(label),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'color': serializer.toJson<int>(color),
      'parentId': serializer.toJson<int?>(parentId),
    };
  }

  MindMapNode copyWith({
    int? id,
    int? mapId,
    String? label,
    double? x,
    double? y,
    int? color,
    Value<int?> parentId = const Value.absent(),
  }) => MindMapNode(
    id: id ?? this.id,
    mapId: mapId ?? this.mapId,
    label: label ?? this.label,
    x: x ?? this.x,
    y: y ?? this.y,
    color: color ?? this.color,
    parentId: parentId.present ? parentId.value : this.parentId,
  );
  MindMapNode copyWithCompanion(MindMapNodesCompanion data) {
    return MindMapNode(
      id: data.id.present ? data.id.value : this.id,
      mapId: data.mapId.present ? data.mapId.value : this.mapId,
      label: data.label.present ? data.label.value : this.label,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      color: data.color.present ? data.color.value : this.color,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MindMapNode(')
          ..write('id: $id, ')
          ..write('mapId: $mapId, ')
          ..write('label: $label, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('color: $color, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mapId, label, x, y, color, parentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MindMapNode &&
          other.id == this.id &&
          other.mapId == this.mapId &&
          other.label == this.label &&
          other.x == this.x &&
          other.y == this.y &&
          other.color == this.color &&
          other.parentId == this.parentId);
}

class MindMapNodesCompanion extends UpdateCompanion<MindMapNode> {
  final Value<int> id;
  final Value<int> mapId;
  final Value<String> label;
  final Value<double> x;
  final Value<double> y;
  final Value<int> color;
  final Value<int?> parentId;
  const MindMapNodesCompanion({
    this.id = const Value.absent(),
    this.mapId = const Value.absent(),
    this.label = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.color = const Value.absent(),
    this.parentId = const Value.absent(),
  });
  MindMapNodesCompanion.insert({
    this.id = const Value.absent(),
    required int mapId,
    required String label,
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.color = const Value.absent(),
    this.parentId = const Value.absent(),
  }) : mapId = Value(mapId),
       label = Value(label);
  static Insertable<MindMapNode> custom({
    Expression<int>? id,
    Expression<int>? mapId,
    Expression<String>? label,
    Expression<double>? x,
    Expression<double>? y,
    Expression<int>? color,
    Expression<int>? parentId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mapId != null) 'map_id': mapId,
      if (label != null) 'label': label,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (color != null) 'color': color,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  MindMapNodesCompanion copyWith({
    Value<int>? id,
    Value<int>? mapId,
    Value<String>? label,
    Value<double>? x,
    Value<double>? y,
    Value<int>? color,
    Value<int?>? parentId,
  }) {
    return MindMapNodesCompanion(
      id: id ?? this.id,
      mapId: mapId ?? this.mapId,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mapId.present) {
      map['map_id'] = Variable<int>(mapId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MindMapNodesCompanion(')
          ..write('id: $id, ')
          ..write('mapId: $mapId, ')
          ..write('label: $label, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('color: $color, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }
}

class $StudySessionsTable extends StudySessions
    with TableInfo<$StudySessionsTable, StudySession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudySessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES school_subjects (id)',
    ),
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    startTime,
    endTime,
    durationMinutes,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudySession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudySession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudySession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      ),
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $StudySessionsTable createAlias(String alias) {
    return $StudySessionsTable(attachedDatabase, alias);
  }
}

class StudySession extends DataClass implements Insertable<StudySession> {
  final int id;
  final int? subjectId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final String? notes;
  const StudySession({
    required this.id,
    this.subjectId,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<int>(subjectId);
    }
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    map['duration_minutes'] = Variable<int>(durationMinutes);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  StudySessionsCompanion toCompanion(bool nullToAbsent) {
    return StudySessionsCompanion(
      id: Value(id),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      startTime: Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      durationMinutes: Value(durationMinutes),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory StudySession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudySession(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int?>(json['subjectId']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int?>(subjectId),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  StudySession copyWith({
    int? id,
    Value<int?> subjectId = const Value.absent(),
    DateTime? startTime,
    Value<DateTime?> endTime = const Value.absent(),
    int? durationMinutes,
    Value<String?> notes = const Value.absent(),
  }) => StudySession(
    id: id ?? this.id,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    startTime: startTime ?? this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    notes: notes.present ? notes.value : this.notes,
  );
  StudySession copyWithCompanion(StudySessionsCompanion data) {
    return StudySession(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudySession(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectId, startTime, endTime, durationMinutes, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudySession &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.durationMinutes == this.durationMinutes &&
          other.notes == this.notes);
}

class StudySessionsCompanion extends UpdateCompanion<StudySession> {
  final Value<int> id;
  final Value<int?> subjectId;
  final Value<DateTime> startTime;
  final Value<DateTime?> endTime;
  final Value<int> durationMinutes;
  final Value<String?> notes;
  const StudySessionsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.notes = const Value.absent(),
  });
  StudySessionsCompanion.insert({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    required DateTime startTime,
    this.endTime = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.notes = const Value.absent(),
  }) : startTime = Value(startTime);
  static Insertable<StudySession> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<int>? durationMinutes,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (notes != null) 'notes': notes,
    });
  }

  StudySessionsCompanion copyWith({
    Value<int>? id,
    Value<int?>? subjectId,
    Value<DateTime>? startTime,
    Value<DateTime?>? endTime,
    Value<int>? durationMinutes,
    Value<String?>? notes,
  }) {
    return StudySessionsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudySessionsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

abstract class _$SchoolDatabase extends GeneratedDatabase {
  _$SchoolDatabase(QueryExecutor e) : super(e);
  $SchoolDatabaseManager get managers => $SchoolDatabaseManager(this);
  late final $SchoolSubjectsTable schoolSubjects = $SchoolSubjectsTable(this);
  late final $AssignmentsTable assignments = $AssignmentsTable(this);
  late final $TimetableEntriesTable timetableEntries = $TimetableEntriesTable(
    this,
  );
  late final $FlashcardDecksTable flashcardDecks = $FlashcardDecksTable(this);
  late final $FlashcardsTable flashcards = $FlashcardsTable(this);
  late final $FormulasTable formulas = $FormulasTable(this);
  late final $GradeComponentsTable gradeComponents = $GradeComponentsTable(
    this,
  );
  late final $GpaRecordsTable gpaRecords = $GpaRecordsTable(this);
  late final $CitationsTable citations = $CitationsTable(this);
  late final $MindMapsTable mindMaps = $MindMapsTable(this);
  late final $MindMapNodesTable mindMapNodes = $MindMapNodesTable(this);
  late final $StudySessionsTable studySessions = $StudySessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    schoolSubjects,
    assignments,
    timetableEntries,
    flashcardDecks,
    flashcards,
    formulas,
    gradeComponents,
    gpaRecords,
    citations,
    mindMaps,
    mindMapNodes,
    studySessions,
  ];
}

typedef $$SchoolSubjectsTableCreateCompanionBuilder =
    SchoolSubjectsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> color,
      Value<double> creditHours,
      Value<bool> archived,
    });
typedef $$SchoolSubjectsTableUpdateCompanionBuilder =
    SchoolSubjectsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> color,
      Value<double> creditHours,
      Value<bool> archived,
    });

final class $$SchoolSubjectsTableReferences
    extends
        BaseReferences<_$SchoolDatabase, $SchoolSubjectsTable, SchoolSubject> {
  $$SchoolSubjectsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$AssignmentsTable, List<Assignment>>
  _assignmentsRefsTable(_$SchoolDatabase db) => MultiTypedResultKey.fromTable(
    db.assignments,
    aliasName: 'school_subjects__id__assignments__subject_id',
  );

  $$AssignmentsTableProcessedTableManager get assignmentsRefs {
    final manager = $$AssignmentsTableTableManager(
      $_db,
      $_db.assignments,
    ).filter((f) => f.subjectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_assignmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TimetableEntriesTable, List<TimetableEntry>>
  _timetableEntriesRefsTable(_$SchoolDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.timetableEntries,
        aliasName: 'school_subjects__id__timetable_entries__subject_id',
      );

  $$TimetableEntriesTableProcessedTableManager get timetableEntriesRefs {
    final manager = $$TimetableEntriesTableTableManager(
      $_db,
      $_db.timetableEntries,
    ).filter((f) => f.subjectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _timetableEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FlashcardDecksTable, List<FlashcardDeck>>
  _flashcardDecksRefsTable(_$SchoolDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.flashcardDecks,
        aliasName: 'school_subjects__id__flashcard_decks__subject_id',
      );

  $$FlashcardDecksTableProcessedTableManager get flashcardDecksRefs {
    final manager = $$FlashcardDecksTableTableManager(
      $_db,
      $_db.flashcardDecks,
    ).filter((f) => f.subjectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_flashcardDecksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GradeComponentsTable, List<GradeComponent>>
  _gradeComponentsRefsTable(_$SchoolDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.gradeComponents,
        aliasName: 'school_subjects__id__grade_components__subject_id',
      );

  $$GradeComponentsTableProcessedTableManager get gradeComponentsRefs {
    final manager = $$GradeComponentsTableTableManager(
      $_db,
      $_db.gradeComponents,
    ).filter((f) => f.subjectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _gradeComponentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GpaRecordsTable, List<GpaRecord>>
  _gpaRecordsRefsTable(_$SchoolDatabase db) => MultiTypedResultKey.fromTable(
    db.gpaRecords,
    aliasName: 'school_subjects__id__gpa_records__subject_id',
  );

  $$GpaRecordsTableProcessedTableManager get gpaRecordsRefs {
    final manager = $$GpaRecordsTableTableManager(
      $_db,
      $_db.gpaRecords,
    ).filter((f) => f.subjectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gpaRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StudySessionsTable, List<StudySession>>
  _studySessionsRefsTable(_$SchoolDatabase db) => MultiTypedResultKey.fromTable(
    db.studySessions,
    aliasName: 'school_subjects__id__study_sessions__subject_id',
  );

  $$StudySessionsTableProcessedTableManager get studySessionsRefs {
    final manager = $$StudySessionsTableTableManager(
      $_db,
      $_db.studySessions,
    ).filter((f) => f.subjectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_studySessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SchoolSubjectsTableFilterComposer
    extends Composer<_$SchoolDatabase, $SchoolSubjectsTable> {
  $$SchoolSubjectsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get creditHours => $composableBuilder(
    column: $table.creditHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> assignmentsRefs(
    Expression<bool> Function($$AssignmentsTableFilterComposer f) f,
  ) {
    final $$AssignmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assignments,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssignmentsTableFilterComposer(
            $db: $db,
            $table: $db.assignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> timetableEntriesRefs(
    Expression<bool> Function($$TimetableEntriesTableFilterComposer f) f,
  ) {
    final $$TimetableEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timetableEntries,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimetableEntriesTableFilterComposer(
            $db: $db,
            $table: $db.timetableEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> flashcardDecksRefs(
    Expression<bool> Function($$FlashcardDecksTableFilterComposer f) f,
  ) {
    final $$FlashcardDecksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcardDecks,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardDecksTableFilterComposer(
            $db: $db,
            $table: $db.flashcardDecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> gradeComponentsRefs(
    Expression<bool> Function($$GradeComponentsTableFilterComposer f) f,
  ) {
    final $$GradeComponentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gradeComponents,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GradeComponentsTableFilterComposer(
            $db: $db,
            $table: $db.gradeComponents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> gpaRecordsRefs(
    Expression<bool> Function($$GpaRecordsTableFilterComposer f) f,
  ) {
    final $$GpaRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gpaRecords,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GpaRecordsTableFilterComposer(
            $db: $db,
            $table: $db.gpaRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> studySessionsRefs(
    Expression<bool> Function($$StudySessionsTableFilterComposer f) f,
  ) {
    final $$StudySessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studySessions,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudySessionsTableFilterComposer(
            $db: $db,
            $table: $db.studySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SchoolSubjectsTableOrderingComposer
    extends Composer<_$SchoolDatabase, $SchoolSubjectsTable> {
  $$SchoolSubjectsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get creditHours => $composableBuilder(
    column: $table.creditHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SchoolSubjectsTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $SchoolSubjectsTable> {
  $$SchoolSubjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get creditHours => $composableBuilder(
    column: $table.creditHours,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  Expression<T> assignmentsRefs<T extends Object>(
    Expression<T> Function($$AssignmentsTableAnnotationComposer a) f,
  ) {
    final $$AssignmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assignments,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssignmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.assignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> timetableEntriesRefs<T extends Object>(
    Expression<T> Function($$TimetableEntriesTableAnnotationComposer a) f,
  ) {
    final $$TimetableEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timetableEntries,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimetableEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.timetableEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> flashcardDecksRefs<T extends Object>(
    Expression<T> Function($$FlashcardDecksTableAnnotationComposer a) f,
  ) {
    final $$FlashcardDecksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcardDecks,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardDecksTableAnnotationComposer(
            $db: $db,
            $table: $db.flashcardDecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> gradeComponentsRefs<T extends Object>(
    Expression<T> Function($$GradeComponentsTableAnnotationComposer a) f,
  ) {
    final $$GradeComponentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gradeComponents,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GradeComponentsTableAnnotationComposer(
            $db: $db,
            $table: $db.gradeComponents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> gpaRecordsRefs<T extends Object>(
    Expression<T> Function($$GpaRecordsTableAnnotationComposer a) f,
  ) {
    final $$GpaRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gpaRecords,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GpaRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.gpaRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> studySessionsRefs<T extends Object>(
    Expression<T> Function($$StudySessionsTableAnnotationComposer a) f,
  ) {
    final $$StudySessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studySessions,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudySessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.studySessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SchoolSubjectsTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $SchoolSubjectsTable,
          SchoolSubject,
          $$SchoolSubjectsTableFilterComposer,
          $$SchoolSubjectsTableOrderingComposer,
          $$SchoolSubjectsTableAnnotationComposer,
          $$SchoolSubjectsTableCreateCompanionBuilder,
          $$SchoolSubjectsTableUpdateCompanionBuilder,
          (SchoolSubject, $$SchoolSubjectsTableReferences),
          SchoolSubject,
          PrefetchHooks Function({
            bool assignmentsRefs,
            bool timetableEntriesRefs,
            bool flashcardDecksRefs,
            bool gradeComponentsRefs,
            bool gpaRecordsRefs,
            bool studySessionsRefs,
          })
        > {
  $$SchoolSubjectsTableTableManager(
    _$SchoolDatabase db,
    $SchoolSubjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchoolSubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchoolSubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchoolSubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<double> creditHours = const Value.absent(),
                Value<bool> archived = const Value.absent(),
              }) => SchoolSubjectsCompanion(
                id: id,
                name: name,
                color: color,
                creditHours: creditHours,
                archived: archived,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> color = const Value.absent(),
                Value<double> creditHours = const Value.absent(),
                Value<bool> archived = const Value.absent(),
              }) => SchoolSubjectsCompanion.insert(
                id: id,
                name: name,
                color: color,
                creditHours: creditHours,
                archived: archived,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SchoolSubjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                assignmentsRefs = false,
                timetableEntriesRefs = false,
                flashcardDecksRefs = false,
                gradeComponentsRefs = false,
                gpaRecordsRefs = false,
                studySessionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (assignmentsRefs) db.assignments,
                    if (timetableEntriesRefs) db.timetableEntries,
                    if (flashcardDecksRefs) db.flashcardDecks,
                    if (gradeComponentsRefs) db.gradeComponents,
                    if (gpaRecordsRefs) db.gpaRecords,
                    if (studySessionsRefs) db.studySessions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (assignmentsRefs)
                        await $_getPrefetchedData<
                          SchoolSubject,
                          $SchoolSubjectsTable,
                          Assignment
                        >(
                          currentTable: table,
                          referencedTable: $$SchoolSubjectsTableReferences
                              ._assignmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SchoolSubjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).assignmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subjectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (timetableEntriesRefs)
                        await $_getPrefetchedData<
                          SchoolSubject,
                          $SchoolSubjectsTable,
                          TimetableEntry
                        >(
                          currentTable: table,
                          referencedTable: $$SchoolSubjectsTableReferences
                              ._timetableEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SchoolSubjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).timetableEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subjectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (flashcardDecksRefs)
                        await $_getPrefetchedData<
                          SchoolSubject,
                          $SchoolSubjectsTable,
                          FlashcardDeck
                        >(
                          currentTable: table,
                          referencedTable: $$SchoolSubjectsTableReferences
                              ._flashcardDecksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SchoolSubjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).flashcardDecksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subjectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (gradeComponentsRefs)
                        await $_getPrefetchedData<
                          SchoolSubject,
                          $SchoolSubjectsTable,
                          GradeComponent
                        >(
                          currentTable: table,
                          referencedTable: $$SchoolSubjectsTableReferences
                              ._gradeComponentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SchoolSubjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).gradeComponentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subjectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (gpaRecordsRefs)
                        await $_getPrefetchedData<
                          SchoolSubject,
                          $SchoolSubjectsTable,
                          GpaRecord
                        >(
                          currentTable: table,
                          referencedTable: $$SchoolSubjectsTableReferences
                              ._gpaRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SchoolSubjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).gpaRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subjectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (studySessionsRefs)
                        await $_getPrefetchedData<
                          SchoolSubject,
                          $SchoolSubjectsTable,
                          StudySession
                        >(
                          currentTable: table,
                          referencedTable: $$SchoolSubjectsTableReferences
                              ._studySessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SchoolSubjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).studySessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subjectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SchoolSubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $SchoolSubjectsTable,
      SchoolSubject,
      $$SchoolSubjectsTableFilterComposer,
      $$SchoolSubjectsTableOrderingComposer,
      $$SchoolSubjectsTableAnnotationComposer,
      $$SchoolSubjectsTableCreateCompanionBuilder,
      $$SchoolSubjectsTableUpdateCompanionBuilder,
      (SchoolSubject, $$SchoolSubjectsTableReferences),
      SchoolSubject,
      PrefetchHooks Function({
        bool assignmentsRefs,
        bool timetableEntriesRefs,
        bool flashcardDecksRefs,
        bool gradeComponentsRefs,
        bool gpaRecordsRefs,
        bool studySessionsRefs,
      })
    >;
typedef $$AssignmentsTableCreateCompanionBuilder =
    AssignmentsCompanion Function({
      Value<int> id,
      Value<int?> subjectId,
      required String title,
      Value<String?> notes,
      required DateTime dueDate,
      Value<int> priority,
      Value<bool> completed,
      Value<DateTime?> completedAt,
      Value<double?> gradeEarned,
      Value<double?> gradeTotal,
      Value<DateTime> createdAt,
    });
typedef $$AssignmentsTableUpdateCompanionBuilder =
    AssignmentsCompanion Function({
      Value<int> id,
      Value<int?> subjectId,
      Value<String> title,
      Value<String?> notes,
      Value<DateTime> dueDate,
      Value<int> priority,
      Value<bool> completed,
      Value<DateTime?> completedAt,
      Value<double?> gradeEarned,
      Value<double?> gradeTotal,
      Value<DateTime> createdAt,
    });

final class $$AssignmentsTableReferences
    extends BaseReferences<_$SchoolDatabase, $AssignmentsTable, Assignment> {
  $$AssignmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SchoolSubjectsTable _subjectIdTable(_$SchoolDatabase db) => db
      .schoolSubjects
      .createAlias('assignments__subject_id__school_subjects__id');

  $$SchoolSubjectsTableProcessedTableManager? get subjectId {
    final $_column = $_itemColumn<int>('subject_id');
    if ($_column == null) return null;
    final manager = $$SchoolSubjectsTableTableManager(
      $_db,
      $_db.schoolSubjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subjectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssignmentsTableFilterComposer
    extends Composer<_$SchoolDatabase, $AssignmentsTable> {
  $$AssignmentsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gradeEarned => $composableBuilder(
    column: $table.gradeEarned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gradeTotal => $composableBuilder(
    column: $table.gradeTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SchoolSubjectsTableFilterComposer get subjectId {
    final $$SchoolSubjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableFilterComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssignmentsTableOrderingComposer
    extends Composer<_$SchoolDatabase, $AssignmentsTable> {
  $$AssignmentsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gradeEarned => $composableBuilder(
    column: $table.gradeEarned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gradeTotal => $composableBuilder(
    column: $table.gradeTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SchoolSubjectsTableOrderingComposer get subjectId {
    final $$SchoolSubjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableOrderingComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssignmentsTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $AssignmentsTable> {
  $$AssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gradeEarned => $composableBuilder(
    column: $table.gradeEarned,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gradeTotal => $composableBuilder(
    column: $table.gradeTotal,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SchoolSubjectsTableAnnotationComposer get subjectId {
    final $$SchoolSubjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssignmentsTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $AssignmentsTable,
          Assignment,
          $$AssignmentsTableFilterComposer,
          $$AssignmentsTableOrderingComposer,
          $$AssignmentsTableAnnotationComposer,
          $$AssignmentsTableCreateCompanionBuilder,
          $$AssignmentsTableUpdateCompanionBuilder,
          (Assignment, $$AssignmentsTableReferences),
          Assignment,
          PrefetchHooks Function({bool subjectId})
        > {
  $$AssignmentsTableTableManager(_$SchoolDatabase db, $AssignmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssignmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssignmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssignmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> subjectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<double?> gradeEarned = const Value.absent(),
                Value<double?> gradeTotal = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AssignmentsCompanion(
                id: id,
                subjectId: subjectId,
                title: title,
                notes: notes,
                dueDate: dueDate,
                priority: priority,
                completed: completed,
                completedAt: completedAt,
                gradeEarned: gradeEarned,
                gradeTotal: gradeTotal,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> subjectId = const Value.absent(),
                required String title,
                Value<String?> notes = const Value.absent(),
                required DateTime dueDate,
                Value<int> priority = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<double?> gradeEarned = const Value.absent(),
                Value<double?> gradeTotal = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AssignmentsCompanion.insert(
                id: id,
                subjectId: subjectId,
                title: title,
                notes: notes,
                dueDate: dueDate,
                priority: priority,
                completed: completed,
                completedAt: completedAt,
                gradeEarned: gradeEarned,
                gradeTotal: gradeTotal,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssignmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subjectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subjectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subjectId,
                                referencedTable: $$AssignmentsTableReferences
                                    ._subjectIdTable(db),
                                referencedColumn: $$AssignmentsTableReferences
                                    ._subjectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $AssignmentsTable,
      Assignment,
      $$AssignmentsTableFilterComposer,
      $$AssignmentsTableOrderingComposer,
      $$AssignmentsTableAnnotationComposer,
      $$AssignmentsTableCreateCompanionBuilder,
      $$AssignmentsTableUpdateCompanionBuilder,
      (Assignment, $$AssignmentsTableReferences),
      Assignment,
      PrefetchHooks Function({bool subjectId})
    >;
typedef $$TimetableEntriesTableCreateCompanionBuilder =
    TimetableEntriesCompanion Function({
      Value<int> id,
      required int subjectId,
      required int dayOfWeek,
      required int startMinutes,
      required int endMinutes,
      Value<String?> location,
      Value<String?> instructor,
    });
typedef $$TimetableEntriesTableUpdateCompanionBuilder =
    TimetableEntriesCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<int> dayOfWeek,
      Value<int> startMinutes,
      Value<int> endMinutes,
      Value<String?> location,
      Value<String?> instructor,
    });

final class $$TimetableEntriesTableReferences
    extends
        BaseReferences<
          _$SchoolDatabase,
          $TimetableEntriesTable,
          TimetableEntry
        > {
  $$TimetableEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SchoolSubjectsTable _subjectIdTable(_$SchoolDatabase db) => db
      .schoolSubjects
      .createAlias('timetable_entries__subject_id__school_subjects__id');

  $$SchoolSubjectsTableProcessedTableManager get subjectId {
    final $_column = $_itemColumn<int>('subject_id')!;

    final manager = $$SchoolSubjectsTableTableManager(
      $_db,
      $_db.schoolSubjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subjectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TimetableEntriesTableFilterComposer
    extends Composer<_$SchoolDatabase, $TimetableEntriesTable> {
  $$TimetableEntriesTableFilterComposer({
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

  ColumnFilters<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinutes => $composableBuilder(
    column: $table.startMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinutes => $composableBuilder(
    column: $table.endMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instructor => $composableBuilder(
    column: $table.instructor,
    builder: (column) => ColumnFilters(column),
  );

  $$SchoolSubjectsTableFilterComposer get subjectId {
    final $$SchoolSubjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableFilterComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimetableEntriesTableOrderingComposer
    extends Composer<_$SchoolDatabase, $TimetableEntriesTable> {
  $$TimetableEntriesTableOrderingComposer({
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

  ColumnOrderings<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinutes => $composableBuilder(
    column: $table.startMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinutes => $composableBuilder(
    column: $table.endMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instructor => $composableBuilder(
    column: $table.instructor,
    builder: (column) => ColumnOrderings(column),
  );

  $$SchoolSubjectsTableOrderingComposer get subjectId {
    final $$SchoolSubjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableOrderingComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimetableEntriesTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $TimetableEntriesTable> {
  $$TimetableEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<int> get startMinutes => $composableBuilder(
    column: $table.startMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinutes => $composableBuilder(
    column: $table.endMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get instructor => $composableBuilder(
    column: $table.instructor,
    builder: (column) => column,
  );

  $$SchoolSubjectsTableAnnotationComposer get subjectId {
    final $$SchoolSubjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimetableEntriesTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $TimetableEntriesTable,
          TimetableEntry,
          $$TimetableEntriesTableFilterComposer,
          $$TimetableEntriesTableOrderingComposer,
          $$TimetableEntriesTableAnnotationComposer,
          $$TimetableEntriesTableCreateCompanionBuilder,
          $$TimetableEntriesTableUpdateCompanionBuilder,
          (TimetableEntry, $$TimetableEntriesTableReferences),
          TimetableEntry,
          PrefetchHooks Function({bool subjectId})
        > {
  $$TimetableEntriesTableTableManager(
    _$SchoolDatabase db,
    $TimetableEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimetableEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimetableEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimetableEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<int> dayOfWeek = const Value.absent(),
                Value<int> startMinutes = const Value.absent(),
                Value<int> endMinutes = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> instructor = const Value.absent(),
              }) => TimetableEntriesCompanion(
                id: id,
                subjectId: subjectId,
                dayOfWeek: dayOfWeek,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                location: location,
                instructor: instructor,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required int dayOfWeek,
                required int startMinutes,
                required int endMinutes,
                Value<String?> location = const Value.absent(),
                Value<String?> instructor = const Value.absent(),
              }) => TimetableEntriesCompanion.insert(
                id: id,
                subjectId: subjectId,
                dayOfWeek: dayOfWeek,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                location: location,
                instructor: instructor,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TimetableEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subjectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subjectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subjectId,
                                referencedTable:
                                    $$TimetableEntriesTableReferences
                                        ._subjectIdTable(db),
                                referencedColumn:
                                    $$TimetableEntriesTableReferences
                                        ._subjectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TimetableEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $TimetableEntriesTable,
      TimetableEntry,
      $$TimetableEntriesTableFilterComposer,
      $$TimetableEntriesTableOrderingComposer,
      $$TimetableEntriesTableAnnotationComposer,
      $$TimetableEntriesTableCreateCompanionBuilder,
      $$TimetableEntriesTableUpdateCompanionBuilder,
      (TimetableEntry, $$TimetableEntriesTableReferences),
      TimetableEntry,
      PrefetchHooks Function({bool subjectId})
    >;
typedef $$FlashcardDecksTableCreateCompanionBuilder =
    FlashcardDecksCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> subjectId,
      Value<DateTime> createdAt,
    });
typedef $$FlashcardDecksTableUpdateCompanionBuilder =
    FlashcardDecksCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> subjectId,
      Value<DateTime> createdAt,
    });

final class $$FlashcardDecksTableReferences
    extends
        BaseReferences<_$SchoolDatabase, $FlashcardDecksTable, FlashcardDeck> {
  $$FlashcardDecksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SchoolSubjectsTable _subjectIdTable(_$SchoolDatabase db) => db
      .schoolSubjects
      .createAlias('flashcard_decks__subject_id__school_subjects__id');

  $$SchoolSubjectsTableProcessedTableManager? get subjectId {
    final $_column = $_itemColumn<int>('subject_id');
    if ($_column == null) return null;
    final manager = $$SchoolSubjectsTableTableManager(
      $_db,
      $_db.schoolSubjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subjectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FlashcardsTable, List<Flashcard>>
  _flashcardsRefsTable(_$SchoolDatabase db) => MultiTypedResultKey.fromTable(
    db.flashcards,
    aliasName: 'flashcard_decks__id__flashcards__deck_id',
  );

  $$FlashcardsTableProcessedTableManager get flashcardsRefs {
    final manager = $$FlashcardsTableTableManager(
      $_db,
      $_db.flashcards,
    ).filter((f) => f.deckId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_flashcardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FlashcardDecksTableFilterComposer
    extends Composer<_$SchoolDatabase, $FlashcardDecksTable> {
  $$FlashcardDecksTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SchoolSubjectsTableFilterComposer get subjectId {
    final $$SchoolSubjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableFilterComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> flashcardsRefs(
    Expression<bool> Function($$FlashcardsTableFilterComposer f) f,
  ) {
    final $$FlashcardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableFilterComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FlashcardDecksTableOrderingComposer
    extends Composer<_$SchoolDatabase, $FlashcardDecksTable> {
  $$FlashcardDecksTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SchoolSubjectsTableOrderingComposer get subjectId {
    final $$SchoolSubjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableOrderingComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlashcardDecksTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $FlashcardDecksTable> {
  $$FlashcardDecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SchoolSubjectsTableAnnotationComposer get subjectId {
    final $$SchoolSubjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> flashcardsRefs<T extends Object>(
    Expression<T> Function($$FlashcardsTableAnnotationComposer a) f,
  ) {
    final $$FlashcardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableAnnotationComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FlashcardDecksTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $FlashcardDecksTable,
          FlashcardDeck,
          $$FlashcardDecksTableFilterComposer,
          $$FlashcardDecksTableOrderingComposer,
          $$FlashcardDecksTableAnnotationComposer,
          $$FlashcardDecksTableCreateCompanionBuilder,
          $$FlashcardDecksTableUpdateCompanionBuilder,
          (FlashcardDeck, $$FlashcardDecksTableReferences),
          FlashcardDeck,
          PrefetchHooks Function({bool subjectId, bool flashcardsRefs})
        > {
  $$FlashcardDecksTableTableManager(
    _$SchoolDatabase db,
    $FlashcardDecksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlashcardDecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlashcardDecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlashcardDecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> subjectId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FlashcardDecksCompanion(
                id: id,
                name: name,
                subjectId: subjectId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> subjectId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FlashcardDecksCompanion.insert(
                id: id,
                name: name,
                subjectId: subjectId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FlashcardDecksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subjectId = false, flashcardsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (flashcardsRefs) db.flashcards],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subjectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subjectId,
                                referencedTable: $$FlashcardDecksTableReferences
                                    ._subjectIdTable(db),
                                referencedColumn:
                                    $$FlashcardDecksTableReferences
                                        ._subjectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (flashcardsRefs)
                    await $_getPrefetchedData<
                      FlashcardDeck,
                      $FlashcardDecksTable,
                      Flashcard
                    >(
                      currentTable: table,
                      referencedTable: $$FlashcardDecksTableReferences
                          ._flashcardsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FlashcardDecksTableReferences(
                            db,
                            table,
                            p0,
                          ).flashcardsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.deckId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FlashcardDecksTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $FlashcardDecksTable,
      FlashcardDeck,
      $$FlashcardDecksTableFilterComposer,
      $$FlashcardDecksTableOrderingComposer,
      $$FlashcardDecksTableAnnotationComposer,
      $$FlashcardDecksTableCreateCompanionBuilder,
      $$FlashcardDecksTableUpdateCompanionBuilder,
      (FlashcardDeck, $$FlashcardDecksTableReferences),
      FlashcardDeck,
      PrefetchHooks Function({bool subjectId, bool flashcardsRefs})
    >;
typedef $$FlashcardsTableCreateCompanionBuilder =
    FlashcardsCompanion Function({
      Value<int> id,
      required int deckId,
      required String front,
      required String back,
      Value<double> easeFactor,
      Value<int> intervalDays,
      Value<int> repetitions,
      Value<DateTime> nextReviewDate,
      Value<DateTime?> lastReviewedAt,
    });
typedef $$FlashcardsTableUpdateCompanionBuilder =
    FlashcardsCompanion Function({
      Value<int> id,
      Value<int> deckId,
      Value<String> front,
      Value<String> back,
      Value<double> easeFactor,
      Value<int> intervalDays,
      Value<int> repetitions,
      Value<DateTime> nextReviewDate,
      Value<DateTime?> lastReviewedAt,
    });

final class $$FlashcardsTableReferences
    extends BaseReferences<_$SchoolDatabase, $FlashcardsTable, Flashcard> {
  $$FlashcardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FlashcardDecksTable _deckIdTable(_$SchoolDatabase db) =>
      db.flashcardDecks.createAlias('flashcards__deck_id__flashcard_decks__id');

  $$FlashcardDecksTableProcessedTableManager get deckId {
    final $_column = $_itemColumn<int>('deck_id')!;

    final manager = $$FlashcardDecksTableTableManager(
      $_db,
      $_db.flashcardDecks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deckIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FlashcardsTableFilterComposer
    extends Composer<_$SchoolDatabase, $FlashcardsTable> {
  $$FlashcardsTableFilterComposer({
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

  ColumnFilters<String> get front => $composableBuilder(
    column: $table.front,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get back => $composableBuilder(
    column: $table.back,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextReviewDate => $composableBuilder(
    column: $table.nextReviewDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FlashcardDecksTableFilterComposer get deckId {
    final $$FlashcardDecksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.flashcardDecks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardDecksTableFilterComposer(
            $db: $db,
            $table: $db.flashcardDecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlashcardsTableOrderingComposer
    extends Composer<_$SchoolDatabase, $FlashcardsTable> {
  $$FlashcardsTableOrderingComposer({
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

  ColumnOrderings<String> get front => $composableBuilder(
    column: $table.front,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get back => $composableBuilder(
    column: $table.back,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextReviewDate => $composableBuilder(
    column: $table.nextReviewDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FlashcardDecksTableOrderingComposer get deckId {
    final $$FlashcardDecksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.flashcardDecks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardDecksTableOrderingComposer(
            $db: $db,
            $table: $db.flashcardDecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlashcardsTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $FlashcardsTable> {
  $$FlashcardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get front =>
      $composableBuilder(column: $table.front, builder: (column) => column);

  GeneratedColumn<String> get back =>
      $composableBuilder(column: $table.back, builder: (column) => column);

  GeneratedColumn<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextReviewDate => $composableBuilder(
    column: $table.nextReviewDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => column,
  );

  $$FlashcardDecksTableAnnotationComposer get deckId {
    final $$FlashcardDecksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.flashcardDecks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardDecksTableAnnotationComposer(
            $db: $db,
            $table: $db.flashcardDecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlashcardsTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $FlashcardsTable,
          Flashcard,
          $$FlashcardsTableFilterComposer,
          $$FlashcardsTableOrderingComposer,
          $$FlashcardsTableAnnotationComposer,
          $$FlashcardsTableCreateCompanionBuilder,
          $$FlashcardsTableUpdateCompanionBuilder,
          (Flashcard, $$FlashcardsTableReferences),
          Flashcard,
          PrefetchHooks Function({bool deckId})
        > {
  $$FlashcardsTableTableManager(_$SchoolDatabase db, $FlashcardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlashcardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlashcardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlashcardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> deckId = const Value.absent(),
                Value<String> front = const Value.absent(),
                Value<String> back = const Value.absent(),
                Value<double> easeFactor = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> repetitions = const Value.absent(),
                Value<DateTime> nextReviewDate = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
              }) => FlashcardsCompanion(
                id: id,
                deckId: deckId,
                front: front,
                back: back,
                easeFactor: easeFactor,
                intervalDays: intervalDays,
                repetitions: repetitions,
                nextReviewDate: nextReviewDate,
                lastReviewedAt: lastReviewedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int deckId,
                required String front,
                required String back,
                Value<double> easeFactor = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> repetitions = const Value.absent(),
                Value<DateTime> nextReviewDate = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
              }) => FlashcardsCompanion.insert(
                id: id,
                deckId: deckId,
                front: front,
                back: back,
                easeFactor: easeFactor,
                intervalDays: intervalDays,
                repetitions: repetitions,
                nextReviewDate: nextReviewDate,
                lastReviewedAt: lastReviewedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FlashcardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deckId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (deckId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deckId,
                                referencedTable: $$FlashcardsTableReferences
                                    ._deckIdTable(db),
                                referencedColumn: $$FlashcardsTableReferences
                                    ._deckIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FlashcardsTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $FlashcardsTable,
      Flashcard,
      $$FlashcardsTableFilterComposer,
      $$FlashcardsTableOrderingComposer,
      $$FlashcardsTableAnnotationComposer,
      $$FlashcardsTableCreateCompanionBuilder,
      $$FlashcardsTableUpdateCompanionBuilder,
      (Flashcard, $$FlashcardsTableReferences),
      Flashcard,
      PrefetchHooks Function({bool deckId})
    >;
typedef $$FormulasTableCreateCompanionBuilder =
    FormulasCompanion Function({
      Value<int> id,
      Value<String> category,
      required String name,
      required String expression,
      Value<String?> description,
      Value<DateTime> createdAt,
    });
typedef $$FormulasTableUpdateCompanionBuilder =
    FormulasCompanion Function({
      Value<int> id,
      Value<String> category,
      Value<String> name,
      Value<String> expression,
      Value<String?> description,
      Value<DateTime> createdAt,
    });

class $$FormulasTableFilterComposer
    extends Composer<_$SchoolDatabase, $FormulasTable> {
  $$FormulasTableFilterComposer({
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

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FormulasTableOrderingComposer
    extends Composer<_$SchoolDatabase, $FormulasTable> {
  $$FormulasTableOrderingComposer({
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

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FormulasTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $FormulasTable> {
  $$FormulasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FormulasTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $FormulasTable,
          Formula,
          $$FormulasTableFilterComposer,
          $$FormulasTableOrderingComposer,
          $$FormulasTableAnnotationComposer,
          $$FormulasTableCreateCompanionBuilder,
          $$FormulasTableUpdateCompanionBuilder,
          (Formula, BaseReferences<_$SchoolDatabase, $FormulasTable, Formula>),
          Formula,
          PrefetchHooks Function()
        > {
  $$FormulasTableTableManager(_$SchoolDatabase db, $FormulasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FormulasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FormulasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FormulasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> expression = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FormulasCompanion(
                id: id,
                category: category,
                name: name,
                expression: expression,
                description: description,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                required String name,
                required String expression,
                Value<String?> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FormulasCompanion.insert(
                id: id,
                category: category,
                name: name,
                expression: expression,
                description: description,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FormulasTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $FormulasTable,
      Formula,
      $$FormulasTableFilterComposer,
      $$FormulasTableOrderingComposer,
      $$FormulasTableAnnotationComposer,
      $$FormulasTableCreateCompanionBuilder,
      $$FormulasTableUpdateCompanionBuilder,
      (Formula, BaseReferences<_$SchoolDatabase, $FormulasTable, Formula>),
      Formula,
      PrefetchHooks Function()
    >;
typedef $$GradeComponentsTableCreateCompanionBuilder =
    GradeComponentsCompanion Function({
      Value<int> id,
      required int subjectId,
      required String name,
      required double weightPercent,
      Value<double?> scoreEarned,
      Value<double> scoreTotal,
    });
typedef $$GradeComponentsTableUpdateCompanionBuilder =
    GradeComponentsCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<String> name,
      Value<double> weightPercent,
      Value<double?> scoreEarned,
      Value<double> scoreTotal,
    });

final class $$GradeComponentsTableReferences
    extends
        BaseReferences<
          _$SchoolDatabase,
          $GradeComponentsTable,
          GradeComponent
        > {
  $$GradeComponentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SchoolSubjectsTable _subjectIdTable(_$SchoolDatabase db) => db
      .schoolSubjects
      .createAlias('grade_components__subject_id__school_subjects__id');

  $$SchoolSubjectsTableProcessedTableManager get subjectId {
    final $_column = $_itemColumn<int>('subject_id')!;

    final manager = $$SchoolSubjectsTableTableManager(
      $_db,
      $_db.schoolSubjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subjectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GradeComponentsTableFilterComposer
    extends Composer<_$SchoolDatabase, $GradeComponentsTable> {
  $$GradeComponentsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightPercent => $composableBuilder(
    column: $table.weightPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scoreEarned => $composableBuilder(
    column: $table.scoreEarned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scoreTotal => $composableBuilder(
    column: $table.scoreTotal,
    builder: (column) => ColumnFilters(column),
  );

  $$SchoolSubjectsTableFilterComposer get subjectId {
    final $$SchoolSubjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableFilterComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GradeComponentsTableOrderingComposer
    extends Composer<_$SchoolDatabase, $GradeComponentsTable> {
  $$GradeComponentsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightPercent => $composableBuilder(
    column: $table.weightPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scoreEarned => $composableBuilder(
    column: $table.scoreEarned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scoreTotal => $composableBuilder(
    column: $table.scoreTotal,
    builder: (column) => ColumnOrderings(column),
  );

  $$SchoolSubjectsTableOrderingComposer get subjectId {
    final $$SchoolSubjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableOrderingComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GradeComponentsTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $GradeComponentsTable> {
  $$GradeComponentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get weightPercent => $composableBuilder(
    column: $table.weightPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get scoreEarned => $composableBuilder(
    column: $table.scoreEarned,
    builder: (column) => column,
  );

  GeneratedColumn<double> get scoreTotal => $composableBuilder(
    column: $table.scoreTotal,
    builder: (column) => column,
  );

  $$SchoolSubjectsTableAnnotationComposer get subjectId {
    final $$SchoolSubjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GradeComponentsTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $GradeComponentsTable,
          GradeComponent,
          $$GradeComponentsTableFilterComposer,
          $$GradeComponentsTableOrderingComposer,
          $$GradeComponentsTableAnnotationComposer,
          $$GradeComponentsTableCreateCompanionBuilder,
          $$GradeComponentsTableUpdateCompanionBuilder,
          (GradeComponent, $$GradeComponentsTableReferences),
          GradeComponent,
          PrefetchHooks Function({bool subjectId})
        > {
  $$GradeComponentsTableTableManager(
    _$SchoolDatabase db,
    $GradeComponentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GradeComponentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GradeComponentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GradeComponentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> weightPercent = const Value.absent(),
                Value<double?> scoreEarned = const Value.absent(),
                Value<double> scoreTotal = const Value.absent(),
              }) => GradeComponentsCompanion(
                id: id,
                subjectId: subjectId,
                name: name,
                weightPercent: weightPercent,
                scoreEarned: scoreEarned,
                scoreTotal: scoreTotal,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required String name,
                required double weightPercent,
                Value<double?> scoreEarned = const Value.absent(),
                Value<double> scoreTotal = const Value.absent(),
              }) => GradeComponentsCompanion.insert(
                id: id,
                subjectId: subjectId,
                name: name,
                weightPercent: weightPercent,
                scoreEarned: scoreEarned,
                scoreTotal: scoreTotal,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GradeComponentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subjectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subjectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subjectId,
                                referencedTable:
                                    $$GradeComponentsTableReferences
                                        ._subjectIdTable(db),
                                referencedColumn:
                                    $$GradeComponentsTableReferences
                                        ._subjectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GradeComponentsTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $GradeComponentsTable,
      GradeComponent,
      $$GradeComponentsTableFilterComposer,
      $$GradeComponentsTableOrderingComposer,
      $$GradeComponentsTableAnnotationComposer,
      $$GradeComponentsTableCreateCompanionBuilder,
      $$GradeComponentsTableUpdateCompanionBuilder,
      (GradeComponent, $$GradeComponentsTableReferences),
      GradeComponent,
      PrefetchHooks Function({bool subjectId})
    >;
typedef $$GpaRecordsTableCreateCompanionBuilder =
    GpaRecordsCompanion Function({
      Value<int> id,
      required int subjectId,
      required String termName,
      required double creditHours,
      required double gradePoints,
      Value<DateTime> date,
    });
typedef $$GpaRecordsTableUpdateCompanionBuilder =
    GpaRecordsCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<String> termName,
      Value<double> creditHours,
      Value<double> gradePoints,
      Value<DateTime> date,
    });

final class $$GpaRecordsTableReferences
    extends BaseReferences<_$SchoolDatabase, $GpaRecordsTable, GpaRecord> {
  $$GpaRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SchoolSubjectsTable _subjectIdTable(_$SchoolDatabase db) => db
      .schoolSubjects
      .createAlias('gpa_records__subject_id__school_subjects__id');

  $$SchoolSubjectsTableProcessedTableManager get subjectId {
    final $_column = $_itemColumn<int>('subject_id')!;

    final manager = $$SchoolSubjectsTableTableManager(
      $_db,
      $_db.schoolSubjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subjectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GpaRecordsTableFilterComposer
    extends Composer<_$SchoolDatabase, $GpaRecordsTable> {
  $$GpaRecordsTableFilterComposer({
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

  ColumnFilters<String> get termName => $composableBuilder(
    column: $table.termName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get creditHours => $composableBuilder(
    column: $table.creditHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gradePoints => $composableBuilder(
    column: $table.gradePoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  $$SchoolSubjectsTableFilterComposer get subjectId {
    final $$SchoolSubjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableFilterComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GpaRecordsTableOrderingComposer
    extends Composer<_$SchoolDatabase, $GpaRecordsTable> {
  $$GpaRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get termName => $composableBuilder(
    column: $table.termName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get creditHours => $composableBuilder(
    column: $table.creditHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gradePoints => $composableBuilder(
    column: $table.gradePoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  $$SchoolSubjectsTableOrderingComposer get subjectId {
    final $$SchoolSubjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableOrderingComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GpaRecordsTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $GpaRecordsTable> {
  $$GpaRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get termName =>
      $composableBuilder(column: $table.termName, builder: (column) => column);

  GeneratedColumn<double> get creditHours => $composableBuilder(
    column: $table.creditHours,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gradePoints => $composableBuilder(
    column: $table.gradePoints,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  $$SchoolSubjectsTableAnnotationComposer get subjectId {
    final $$SchoolSubjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GpaRecordsTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $GpaRecordsTable,
          GpaRecord,
          $$GpaRecordsTableFilterComposer,
          $$GpaRecordsTableOrderingComposer,
          $$GpaRecordsTableAnnotationComposer,
          $$GpaRecordsTableCreateCompanionBuilder,
          $$GpaRecordsTableUpdateCompanionBuilder,
          (GpaRecord, $$GpaRecordsTableReferences),
          GpaRecord,
          PrefetchHooks Function({bool subjectId})
        > {
  $$GpaRecordsTableTableManager(_$SchoolDatabase db, $GpaRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GpaRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GpaRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GpaRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> termName = const Value.absent(),
                Value<double> creditHours = const Value.absent(),
                Value<double> gradePoints = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
              }) => GpaRecordsCompanion(
                id: id,
                subjectId: subjectId,
                termName: termName,
                creditHours: creditHours,
                gradePoints: gradePoints,
                date: date,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required String termName,
                required double creditHours,
                required double gradePoints,
                Value<DateTime> date = const Value.absent(),
              }) => GpaRecordsCompanion.insert(
                id: id,
                subjectId: subjectId,
                termName: termName,
                creditHours: creditHours,
                gradePoints: gradePoints,
                date: date,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GpaRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subjectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subjectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subjectId,
                                referencedTable: $$GpaRecordsTableReferences
                                    ._subjectIdTable(db),
                                referencedColumn: $$GpaRecordsTableReferences
                                    ._subjectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GpaRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $GpaRecordsTable,
      GpaRecord,
      $$GpaRecordsTableFilterComposer,
      $$GpaRecordsTableOrderingComposer,
      $$GpaRecordsTableAnnotationComposer,
      $$GpaRecordsTableCreateCompanionBuilder,
      $$GpaRecordsTableUpdateCompanionBuilder,
      (GpaRecord, $$GpaRecordsTableReferences),
      GpaRecord,
      PrefetchHooks Function({bool subjectId})
    >;
typedef $$CitationsTableCreateCompanionBuilder =
    CitationsCompanion Function({
      Value<int> id,
      required String style,
      required String sourceType,
      Value<String> fieldsJson,
      required String formattedText,
      Value<DateTime> createdAt,
    });
typedef $$CitationsTableUpdateCompanionBuilder =
    CitationsCompanion Function({
      Value<int> id,
      Value<String> style,
      Value<String> sourceType,
      Value<String> fieldsJson,
      Value<String> formattedText,
      Value<DateTime> createdAt,
    });

class $$CitationsTableFilterComposer
    extends Composer<_$SchoolDatabase, $CitationsTable> {
  $$CitationsTableFilterComposer({
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

  ColumnFilters<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formattedText => $composableBuilder(
    column: $table.formattedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CitationsTableOrderingComposer
    extends Composer<_$SchoolDatabase, $CitationsTable> {
  $$CitationsTableOrderingComposer({
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

  ColumnOrderings<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formattedText => $composableBuilder(
    column: $table.formattedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CitationsTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $CitationsTable> {
  $$CitationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formattedText => $composableBuilder(
    column: $table.formattedText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CitationsTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $CitationsTable,
          Citation,
          $$CitationsTableFilterComposer,
          $$CitationsTableOrderingComposer,
          $$CitationsTableAnnotationComposer,
          $$CitationsTableCreateCompanionBuilder,
          $$CitationsTableUpdateCompanionBuilder,
          (
            Citation,
            BaseReferences<_$SchoolDatabase, $CitationsTable, Citation>,
          ),
          Citation,
          PrefetchHooks Function()
        > {
  $$CitationsTableTableManager(_$SchoolDatabase db, $CitationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CitationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CitationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CitationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> style = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> fieldsJson = const Value.absent(),
                Value<String> formattedText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CitationsCompanion(
                id: id,
                style: style,
                sourceType: sourceType,
                fieldsJson: fieldsJson,
                formattedText: formattedText,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String style,
                required String sourceType,
                Value<String> fieldsJson = const Value.absent(),
                required String formattedText,
                Value<DateTime> createdAt = const Value.absent(),
              }) => CitationsCompanion.insert(
                id: id,
                style: style,
                sourceType: sourceType,
                fieldsJson: fieldsJson,
                formattedText: formattedText,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CitationsTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $CitationsTable,
      Citation,
      $$CitationsTableFilterComposer,
      $$CitationsTableOrderingComposer,
      $$CitationsTableAnnotationComposer,
      $$CitationsTableCreateCompanionBuilder,
      $$CitationsTableUpdateCompanionBuilder,
      (Citation, BaseReferences<_$SchoolDatabase, $CitationsTable, Citation>),
      Citation,
      PrefetchHooks Function()
    >;
typedef $$MindMapsTableCreateCompanionBuilder =
    MindMapsCompanion Function({
      Value<int> id,
      required String title,
      Value<DateTime> updatedAt,
    });
typedef $$MindMapsTableUpdateCompanionBuilder =
    MindMapsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<DateTime> updatedAt,
    });

final class $$MindMapsTableReferences
    extends BaseReferences<_$SchoolDatabase, $MindMapsTable, MindMap> {
  $$MindMapsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MindMapNodesTable, List<MindMapNode>>
  _mindMapNodesRefsTable(_$SchoolDatabase db) => MultiTypedResultKey.fromTable(
    db.mindMapNodes,
    aliasName: 'mind_maps__id__mind_map_nodes__map_id',
  );

  $$MindMapNodesTableProcessedTableManager get mindMapNodesRefs {
    final manager = $$MindMapNodesTableTableManager(
      $_db,
      $_db.mindMapNodes,
    ).filter((f) => f.mapId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mindMapNodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MindMapsTableFilterComposer
    extends Composer<_$SchoolDatabase, $MindMapsTable> {
  $$MindMapsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mindMapNodesRefs(
    Expression<bool> Function($$MindMapNodesTableFilterComposer f) f,
  ) {
    final $$MindMapNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mindMapNodes,
      getReferencedColumn: (t) => t.mapId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MindMapNodesTableFilterComposer(
            $db: $db,
            $table: $db.mindMapNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MindMapsTableOrderingComposer
    extends Composer<_$SchoolDatabase, $MindMapsTable> {
  $$MindMapsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MindMapsTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $MindMapsTable> {
  $$MindMapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> mindMapNodesRefs<T extends Object>(
    Expression<T> Function($$MindMapNodesTableAnnotationComposer a) f,
  ) {
    final $$MindMapNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mindMapNodes,
      getReferencedColumn: (t) => t.mapId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MindMapNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.mindMapNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MindMapsTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $MindMapsTable,
          MindMap,
          $$MindMapsTableFilterComposer,
          $$MindMapsTableOrderingComposer,
          $$MindMapsTableAnnotationComposer,
          $$MindMapsTableCreateCompanionBuilder,
          $$MindMapsTableUpdateCompanionBuilder,
          (MindMap, $$MindMapsTableReferences),
          MindMap,
          PrefetchHooks Function({bool mindMapNodesRefs})
        > {
  $$MindMapsTableTableManager(_$SchoolDatabase db, $MindMapsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MindMapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MindMapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MindMapsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) =>
                  MindMapsCompanion(id: id, title: title, updatedAt: updatedAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<DateTime> updatedAt = const Value.absent(),
              }) => MindMapsCompanion.insert(
                id: id,
                title: title,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MindMapsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mindMapNodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mindMapNodesRefs) db.mindMapNodes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mindMapNodesRefs)
                    await $_getPrefetchedData<
                      MindMap,
                      $MindMapsTable,
                      MindMapNode
                    >(
                      currentTable: table,
                      referencedTable: $$MindMapsTableReferences
                          ._mindMapNodesRefsTable(db),
                      managerFromTypedResult: (p0) => $$MindMapsTableReferences(
                        db,
                        table,
                        p0,
                      ).mindMapNodesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mapId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MindMapsTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $MindMapsTable,
      MindMap,
      $$MindMapsTableFilterComposer,
      $$MindMapsTableOrderingComposer,
      $$MindMapsTableAnnotationComposer,
      $$MindMapsTableCreateCompanionBuilder,
      $$MindMapsTableUpdateCompanionBuilder,
      (MindMap, $$MindMapsTableReferences),
      MindMap,
      PrefetchHooks Function({bool mindMapNodesRefs})
    >;
typedef $$MindMapNodesTableCreateCompanionBuilder =
    MindMapNodesCompanion Function({
      Value<int> id,
      required int mapId,
      required String label,
      Value<double> x,
      Value<double> y,
      Value<int> color,
      Value<int?> parentId,
    });
typedef $$MindMapNodesTableUpdateCompanionBuilder =
    MindMapNodesCompanion Function({
      Value<int> id,
      Value<int> mapId,
      Value<String> label,
      Value<double> x,
      Value<double> y,
      Value<int> color,
      Value<int?> parentId,
    });

final class $$MindMapNodesTableReferences
    extends BaseReferences<_$SchoolDatabase, $MindMapNodesTable, MindMapNode> {
  $$MindMapNodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MindMapsTable _mapIdTable(_$SchoolDatabase db) =>
      db.mindMaps.createAlias('mind_map_nodes__map_id__mind_maps__id');

  $$MindMapsTableProcessedTableManager get mapId {
    final $_column = $_itemColumn<int>('map_id')!;

    final manager = $$MindMapsTableTableManager(
      $_db,
      $_db.mindMaps,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mapIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MindMapNodesTableFilterComposer
    extends Composer<_$SchoolDatabase, $MindMapNodesTable> {
  $$MindMapNodesTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  $$MindMapsTableFilterComposer get mapId {
    final $$MindMapsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.mindMaps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MindMapsTableFilterComposer(
            $db: $db,
            $table: $db.mindMaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MindMapNodesTableOrderingComposer
    extends Composer<_$SchoolDatabase, $MindMapNodesTable> {
  $$MindMapNodesTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  $$MindMapsTableOrderingComposer get mapId {
    final $$MindMapsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.mindMaps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MindMapsTableOrderingComposer(
            $db: $db,
            $table: $db.mindMaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MindMapNodesTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $MindMapNodesTable> {
  $$MindMapNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  $$MindMapsTableAnnotationComposer get mapId {
    final $$MindMapsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.mindMaps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MindMapsTableAnnotationComposer(
            $db: $db,
            $table: $db.mindMaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MindMapNodesTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $MindMapNodesTable,
          MindMapNode,
          $$MindMapNodesTableFilterComposer,
          $$MindMapNodesTableOrderingComposer,
          $$MindMapNodesTableAnnotationComposer,
          $$MindMapNodesTableCreateCompanionBuilder,
          $$MindMapNodesTableUpdateCompanionBuilder,
          (MindMapNode, $$MindMapNodesTableReferences),
          MindMapNode,
          PrefetchHooks Function({bool mapId})
        > {
  $$MindMapNodesTableTableManager(_$SchoolDatabase db, $MindMapNodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MindMapNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MindMapNodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MindMapNodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mapId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
              }) => MindMapNodesCompanion(
                id: id,
                mapId: mapId,
                label: label,
                x: x,
                y: y,
                color: color,
                parentId: parentId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mapId,
                required String label,
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
              }) => MindMapNodesCompanion.insert(
                id: id,
                mapId: mapId,
                label: label,
                x: x,
                y: y,
                color: color,
                parentId: parentId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MindMapNodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mapId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mapId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mapId,
                                referencedTable: $$MindMapNodesTableReferences
                                    ._mapIdTable(db),
                                referencedColumn: $$MindMapNodesTableReferences
                                    ._mapIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MindMapNodesTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $MindMapNodesTable,
      MindMapNode,
      $$MindMapNodesTableFilterComposer,
      $$MindMapNodesTableOrderingComposer,
      $$MindMapNodesTableAnnotationComposer,
      $$MindMapNodesTableCreateCompanionBuilder,
      $$MindMapNodesTableUpdateCompanionBuilder,
      (MindMapNode, $$MindMapNodesTableReferences),
      MindMapNode,
      PrefetchHooks Function({bool mapId})
    >;
typedef $$StudySessionsTableCreateCompanionBuilder =
    StudySessionsCompanion Function({
      Value<int> id,
      Value<int?> subjectId,
      required DateTime startTime,
      Value<DateTime?> endTime,
      Value<int> durationMinutes,
      Value<String?> notes,
    });
typedef $$StudySessionsTableUpdateCompanionBuilder =
    StudySessionsCompanion Function({
      Value<int> id,
      Value<int?> subjectId,
      Value<DateTime> startTime,
      Value<DateTime?> endTime,
      Value<int> durationMinutes,
      Value<String?> notes,
    });

final class $$StudySessionsTableReferences
    extends
        BaseReferences<_$SchoolDatabase, $StudySessionsTable, StudySession> {
  $$StudySessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SchoolSubjectsTable _subjectIdTable(_$SchoolDatabase db) => db
      .schoolSubjects
      .createAlias('study_sessions__subject_id__school_subjects__id');

  $$SchoolSubjectsTableProcessedTableManager? get subjectId {
    final $_column = $_itemColumn<int>('subject_id');
    if ($_column == null) return null;
    final manager = $$SchoolSubjectsTableTableManager(
      $_db,
      $_db.schoolSubjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subjectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StudySessionsTableFilterComposer
    extends Composer<_$SchoolDatabase, $StudySessionsTable> {
  $$StudySessionsTableFilterComposer({
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

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$SchoolSubjectsTableFilterComposer get subjectId {
    final $$SchoolSubjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableFilterComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudySessionsTableOrderingComposer
    extends Composer<_$SchoolDatabase, $StudySessionsTable> {
  $$StudySessionsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$SchoolSubjectsTableOrderingComposer get subjectId {
    final $$SchoolSubjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableOrderingComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudySessionsTableAnnotationComposer
    extends Composer<_$SchoolDatabase, $StudySessionsTable> {
  $$StudySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$SchoolSubjectsTableAnnotationComposer get subjectId {
    final $$SchoolSubjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.schoolSubjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchoolSubjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.schoolSubjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudySessionsTableTableManager
    extends
        RootTableManager<
          _$SchoolDatabase,
          $StudySessionsTable,
          StudySession,
          $$StudySessionsTableFilterComposer,
          $$StudySessionsTableOrderingComposer,
          $$StudySessionsTableAnnotationComposer,
          $$StudySessionsTableCreateCompanionBuilder,
          $$StudySessionsTableUpdateCompanionBuilder,
          (StudySession, $$StudySessionsTableReferences),
          StudySession,
          PrefetchHooks Function({bool subjectId})
        > {
  $$StudySessionsTableTableManager(
    _$SchoolDatabase db,
    $StudySessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> subjectId = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => StudySessionsCompanion(
                id: id,
                subjectId: subjectId,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> subjectId = const Value.absent(),
                required DateTime startTime,
                Value<DateTime?> endTime = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => StudySessionsCompanion.insert(
                id: id,
                subjectId: subjectId,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StudySessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subjectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subjectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subjectId,
                                referencedTable: $$StudySessionsTableReferences
                                    ._subjectIdTable(db),
                                referencedColumn: $$StudySessionsTableReferences
                                    ._subjectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StudySessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$SchoolDatabase,
      $StudySessionsTable,
      StudySession,
      $$StudySessionsTableFilterComposer,
      $$StudySessionsTableOrderingComposer,
      $$StudySessionsTableAnnotationComposer,
      $$StudySessionsTableCreateCompanionBuilder,
      $$StudySessionsTableUpdateCompanionBuilder,
      (StudySession, $$StudySessionsTableReferences),
      StudySession,
      PrefetchHooks Function({bool subjectId})
    >;

class $SchoolDatabaseManager {
  final _$SchoolDatabase _db;
  $SchoolDatabaseManager(this._db);
  $$SchoolSubjectsTableTableManager get schoolSubjects =>
      $$SchoolSubjectsTableTableManager(_db, _db.schoolSubjects);
  $$AssignmentsTableTableManager get assignments =>
      $$AssignmentsTableTableManager(_db, _db.assignments);
  $$TimetableEntriesTableTableManager get timetableEntries =>
      $$TimetableEntriesTableTableManager(_db, _db.timetableEntries);
  $$FlashcardDecksTableTableManager get flashcardDecks =>
      $$FlashcardDecksTableTableManager(_db, _db.flashcardDecks);
  $$FlashcardsTableTableManager get flashcards =>
      $$FlashcardsTableTableManager(_db, _db.flashcards);
  $$FormulasTableTableManager get formulas =>
      $$FormulasTableTableManager(_db, _db.formulas);
  $$GradeComponentsTableTableManager get gradeComponents =>
      $$GradeComponentsTableTableManager(_db, _db.gradeComponents);
  $$GpaRecordsTableTableManager get gpaRecords =>
      $$GpaRecordsTableTableManager(_db, _db.gpaRecords);
  $$CitationsTableTableManager get citations =>
      $$CitationsTableTableManager(_db, _db.citations);
  $$MindMapsTableTableManager get mindMaps =>
      $$MindMapsTableTableManager(_db, _db.mindMaps);
  $$MindMapNodesTableTableManager get mindMapNodes =>
      $$MindMapNodesTableTableManager(_db, _db.mindMapNodes);
  $$StudySessionsTableTableManager get studySessions =>
      $$StudySessionsTableTableManager(_db, _db.studySessions);
}
