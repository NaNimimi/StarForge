import 'package:flutter/material.dart';

import 'api_client.dart';
import 'data.dart';
import 'store.dart';

typedef _Row = Map<String, dynamic>;

String _text(_Row row, Iterable<String> keys, {String fallback = '—'}) =>
    apiText(apiValue(row, keys), fallback: fallback);

String _id(_Row row) => _text(row, const [
  'id',
  'pk',
  'uuid',
  'student_id',
  'teacher_id',
  'branch_id',
], fallback: '');

int _integer(_Row row, Iterable<String> keys, {int fallback = 0}) =>
    (apiNumber(row, keys) ?? fallback).round();

num _amount(_Row row) =>
    apiNumber(row, const [
      'amount_uzs',
      'total_uzs',
      'amount',
      'total',
      'sum',
      'value',
    ]) ??
    0;

bool _truthy(Object? value) =>
    value == true ||
    value == 1 ||
    const {
      'true',
      '1',
      'yes',
      'active',
      'online',
      'paid',
    }.contains('$value'.trim().toLowerCase());

Map<String, String> _namesById(
  Iterable<_Row> rows, {
  Iterable<String> names = const ['full_name', 'name', 'display_name', 'title'],
}) => <String, String>{
  for (final row in rows)
    if (_id(row).isNotEmpty) _id(row): _text(row, names),
};

String _relation(
  _Row row,
  Iterable<String> keys,
  Map<String, String> names, {
  String fallback = '—',
}) {
  final value = apiValue(row, keys);
  if (value is Map) return apiText(value, fallback: fallback);
  final raw = apiText(value);
  if (raw.isEmpty) return fallback;
  return names[raw] ?? raw;
}

String _date(Object? value) {
  final parsed = apiDate(value);
  if (parsed == null) return apiText(value, fallback: '—');
  return '${parsed.day.toString().padLeft(2, '0')}.'
      '${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
}

String _time(Object? value) {
  final parsed = apiDate(value);
  if (parsed == null) return apiText(value, fallback: '—');
  return '${parsed.hour.toString().padLeft(2, '0')}:'
      '${parsed.minute.toString().padLeft(2, '0')}';
}

int _percentage(num value) =>
    (value.abs() <= 1 ? value * 100 : value).round().clamp(0, 100);

List<_Row> _documentRows(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
  if (value is! Map) return const [];
  final map = Map<String, dynamic>.from(value);
  for (final key in const ['results', 'data', 'items', 'branches']) {
    final rows = _documentRows(map[key]);
    if (rows.isNotEmpty) return rows;
  }
  return const [];
}

/// Projects authenticated API caches into the existing product view models.
/// The screens keep the established product design; values that the backend
/// does not publish remain `—` and are never generated from demo seeds.
void syncProductStoreFromApi(ApiSession session, AppStore store) {
  if (!session.authenticated) return;

  final branchRows = session.records('branches');
  final groupRows = session.records('groups');
  final teacherRows = session.records('teachers');
  final staffRows = session.records('staff');
  final studentRows = session.records('students');
  final parentRows = session.records('parents');
  final paymentRows = session.records('payments');
  final attendanceRows = session.records('attendanceRecords');

  final branchNames = _namesById(branchRows);
  final groupNames = _namesById(groupRows);
  final teacherNames = _namesById(teacherRows);
  final studentNames = _namesById(studentRows);

  final groupById = <String, _Row>{
    for (final row in groupRows)
      if (_id(row).isNotEmpty) _id(row): row,
  };
  final parentByStudent = <String, _Row>{};
  for (final row in parentRows) {
    final student = apiValue(row, const [
      'student_id',
      'student',
      'child_id',
      'child',
      'student_name',
      'child_name',
    ]);
    final key = student is Map
        ? apiText(
            apiValue(Map<String, dynamic>.from(student), const ['id', 'name']),
          )
        : apiText(student);
    if (key.isNotEmpty) parentByStudent[key] = row;
  }

  List<Student>? students;
  if (session.collections.containsKey('students')) {
    students = studentRows
        .map((row) {
          final id = _id(row);
          final groupValue = apiText(
            apiValue(row, const ['group_id', 'group', 'cohort_id', 'cohort']),
          );
          final group = groupById[groupValue];
          final groupName = group == null
              ? _relation(row, const [
                  'group_name',
                  'group',
                  'cohort_name',
                  'cohort',
                ], groupNames)
              : _text(group, const ['name', 'title']);
          final branchName = _relation(
            row,
            const ['branch_name', 'branch', 'branch_id'],
            branchNames,
            fallback: group == null
                ? '—'
                : _relation(group, const [
                    'branch_name',
                    'branch',
                    'branch_id',
                  ], branchNames),
          );
          final relatedAttendance = attendanceRows
              .where((entry) {
                final relation = _relation(
                  entry,
                  const ['student_id', 'student', 'student_name'],
                  studentNames,
                  fallback: '',
                );
                return relation == id ||
                    relation == _text(row, const ['name', 'full_name']);
              })
              .toList(growable: false);
          var attendance = apiNumber(row, const [
            'attendance_percent',
            'attendance_percentage',
            'attendance_rate',
            'attendance',
          ]);
          if (attendance == null && relatedAttendance.isNotEmpty) {
            final present = relatedAttendance.where((entry) {
              final status = _text(entry, const [
                'status',
                'attendance_status',
                'state',
              ], fallback: '').toLowerCase();
              return status.contains('present') ||
                  status.contains('attended') ||
                  status.contains('late') ||
                  _truthy(apiValue(entry, const ['is_present', 'present']));
            }).length;
            attendance = present * 100 / relatedAttendance.length;
          }
          final debt =
              apiNumber(row, const [
                'debt_uzs',
                'debt',
                'debt_amount',
                'outstanding_amount',
                'balance_due',
              ]) ??
              0;
          final active = apiValue(row, const ['is_active', 'active']);
          final rawStatus = _text(row, const [
            'payment_status',
            'pay_status',
            'status',
          ], fallback: '').toLowerCase();
          final paymentState = active != null && !_truthy(active)
              ? 'left'
              : debt > 0
              ? (rawStatus.contains('partial') ? 'partial' : 'debt')
              : 'paid';
          final parent =
              parentByStudent[id] ??
              parentByStudent[_text(row, const ['name', 'full_name'])];
          return Student(
            _text(row, const ['full_name', 'name', 'student_name']),
            groupName,
            _percentage(attendance ?? 0),
            paymentState,
            debt,
            studentNumber: id,
            phone: _text(row, const [
              'phone',
              'phone_number',
              'mobile',
            ], fallback: '—'),
            backupPhone: _text(row, const [
              'backup_phone',
              'secondary_phone',
            ], fallback: '—'),
            parentName: parent == null
                ? '—'
                : _text(parent, const ['full_name', 'name', 'parent_name']),
            parentPhone: parent == null
                ? '—'
                : _text(parent, const ['phone', 'phone_number', 'mobile']),
            branch: branchName,
            username: _text(row, const [
              'username',
              'login',
              'email',
            ], fallback: '—'),
            gender: _text(row, const ['gender', 'sex'], fallback: '—'),
            level: _text(
              row,
              const ['level_name', 'level', 'course_level'],
              fallback: group == null
                  ? '—'
                  : _text(group, const ['level_name', 'level'], fallback: '—'),
            ),
            enrolledAt: _date(
              apiValue(row, const ['enrolled_at', 'start_date', 'created_at']),
            ),
            age: apiNumber(row, const ['age'])?.round(),
            serverBacked: true,
          );
        })
        .toList(growable: false);
  }

  List<ManagedGroup>? groups;
  if (session.collections.containsKey('groups')) {
    groups = groupRows
        .map(
          (row) => ManagedGroup(
            name: _text(row, const ['name', 'title', 'group_name']),
            branch: _relation(row, const [
              'branch_name',
              'branch',
              'branch_id',
            ], branchNames),
            teacher: _relation(row, const [
              'teacher_name',
              'teacher',
              'teacher_id',
              'instructor',
            ], teacherNames),
            schedule: _text(row, const [
              'schedule',
              'lesson_time',
              'time',
            ], fallback: '—'),
            level: _text(row, const [
              'level_name',
              'level',
              'course_level',
            ], fallback: '—'),
            status: _text(row, const ['status', 'state'], fallback: 'active'),
          ),
        )
        .toList(growable: false);
  }

  List<LedgerEntry>? ledger;
  if (session.collections.containsKey('payments')) {
    ledger = paymentRows
        .map((row) {
          final student = _relation(row, const [
            'student_name',
            'student',
            'student_id',
          ], studentNames);
          final created = apiValue(row, const [
            'paid_at',
            'payment_date',
            'created_at',
            'date',
          ]);
          final status = _text(row, const [
            'payment_status',
            'status',
            'state',
          ], fallback: 'accepted');
          final refund =
              status.toLowerCase().contains('refund') ||
              _truthy(apiValue(row, const ['is_refund', 'refunded']));
          return LedgerEntry(
            id: _id(row).isEmpty
                ? _text(row, const ['operation_number', 'transaction_id'])
                : _id(row),
            title: refund ? 'Возврат' : 'Оплата обучения',
            who: student,
            amount: _amount(row),
            inflow: !refund,
            kind: refund ? 'Возврат' : 'Оплата',
            channel: _text(row, const [
              'payment_method',
              'method',
              'channel',
            ], fallback: '—'),
            date: _date(created),
            time: _time(created),
            payer: _text(row, const [
              'payer_name',
              'payer',
              'paid_by',
            ], fallback: student),
            student: student,
            group: _relation(row, const [
              'group_name',
              'group',
              'group_id',
            ], groupNames),
            teacher: _relation(row, const [
              'teacher_name',
              'teacher',
              'teacher_id',
            ], teacherNames),
            branch: _relation(row, const [
              'branch_name',
              'branch',
              'branch_id',
            ], branchNames),
            operationNumber: _text(row, const [
              'operation_number',
              'transaction_number',
              'reference',
              'id',
            ]),
            comment: _text(row, const [
              'comment',
              'notes',
              'description',
            ], fallback: '—'),
            status: status,
          );
        })
        .toList(growable: false);
  }

  List<Branch>? branches;
  if (session.collections.containsKey('branches')) {
    final intelligence = <String, _Row>{};
    for (final row in _documentRows(
      session.documents['intelligenceBranches'],
    )) {
      final key = _text(row, const [
        'branch',
        'branch_id',
        'name',
      ], fallback: '');
      if (key.isNotEmpty) intelligence[key] = row;
    }
    branches = branchRows
        .map((row) {
          final id = _id(row);
          final name = _text(row, const ['name', 'title']);
          final insight = intelligence[id] ?? intelligence[name];
          final matchingStudents = (students ?? const <Student>[])
              .where((student) => student.branch == name)
              .toList(growable: false);
          final matchingLedger = (ledger ?? const <LedgerEntry>[])
              .where((entry) => entry.branch == name && entry.inflow)
              .toList(growable: false);
          final studentsCount = insight == null
              ? _integer(row, const [
                  'active_students',
                  'student_count',
                  'students_count',
                ], fallback: matchingStudents.length)
              : _integer(insight, const [
                  'active_students',
                  'student_count',
                ], fallback: matchingStudents.length);
          final attendanceValue = insight == null
              ? apiNumber(row, const ['attendance_rate', 'attendance'])
              : apiNumber(insight, const ['attendance_rate', 'attendance']);
          final attendance = attendanceValue == null
              ? (matchingStudents.isEmpty
                    ? 0
                    : (matchingStudents.fold<int>(
                                0,
                                (sum, student) => sum + student.attendance,
                              ) /
                              matchingStudents.length)
                          .round())
              : _percentage(attendanceValue);
          final score = insight == null
              ? apiNumber(row, const ['score', 'trend']) ?? 0
              : apiNumber(insight, const ['score', 'trend']) ?? 0;
          final revenue = matchingLedger.fold<num>(
            0,
            (sum, entry) => sum + entry.amount,
          );
          final mark = attendance >= 90
              ? const Color(0xFF4F7B3B)
              : attendance >= 80
              ? const Color(0xFFC68423)
              : const Color(0xFFB33A2A);
          return Branch(
            name,
            revenue,
            studentsCount,
            attendance,
            score.toDouble(),
            mark,
          );
        })
        .toList(growable: false);
  }

  List<Approval>? approvals;
  if (session.collections.containsKey('approvals')) {
    approvals = session
        .records('approvals')
        .map((row) {
          final status = _text(row, const [
            'status',
            'state',
          ], fallback: 'pending');
          final danger = status.toLowerCase().contains('reject');
          return Approval(
            _id(row),
            _text(row, const ['title', 'type', 'action']),
            _text(row, const [
              'requested_by_name',
              'requested_by',
              'actor_name',
            ]),
            _text(row, const ['description', 'reason', 'comment']),
            _amount(row),
            danger ? const Color(0xFFB33A2A) : const Color(0xFF4F7B3B),
            inflow: _truthy(apiValue(row, const ['inflow', 'is_inflow'])),
          );
        })
        .toList(growable: false);
  }

  List<Anomaly>? anomalies;
  if (session.collections.containsKey('studentRisk')) {
    anomalies = session
        .records('studentRisk')
        .map((row) {
          final risk = _text(row, const [
            'risk_level',
            'severity',
            'level',
          ], fallback: 'low').toLowerCase();
          final severity = risk.contains('high') || risk.contains('critical')
              ? 'high'
              : risk.contains('med')
              ? 'med'
              : 'low';
          return Anomaly(
            _text(row, const ['student_name', 'name', 'title', 'reason']),
            _text(row, const ['reason', 'signal', 'kind'], fallback: 'Риск'),
            _relation(row, const [
              'branch_name',
              'branch',
              'branch_id',
            ], branchNames),
            _integer(row, const ['score', 'risk_score']),
            severity,
          );
        })
        .toList(growable: false);
  }

  List<AuditCase>? cases;
  if (session.collections.containsKey('tasks')) {
    cases = session
        .records('tasks')
        .map((row) {
          final severity = _text(row, const [
            'severity',
            'priority',
          ], fallback: 'med');
          return AuditCase(
            _id(row),
            _text(row, const ['title', 'name', 'description']),
            severity,
            _text(row, const ['status', 'state'], fallback: 'open'),
          );
        })
        .toList(growable: false);
  }

  List<ChatThread>? threads;
  if (session.collections.containsKey('threads')) {
    threads = session
        .records('threads')
        .map((row) {
          final last = _text(row, const [
            'last_message',
            'message',
            'preview',
          ], fallback: '');
          final meta = Thread(
            _text(row, const ['name', 'title', 'display_name']),
            _text(row, const [
              'group_name',
              'group',
              'type',
            ], fallback: 'Диалог'),
            last,
            _time(apiValue(row, const ['updated_at', 'last_message_at'])),
            unread: _integer(row, const ['unread_count', 'unread']),
            online: _truthy(apiValue(row, const ['online', 'is_online'])),
            isGroup: _truthy(apiValue(row, const ['is_group', 'group_chat'])),
          );
          return ChatThread(meta, [
            if (last.isNotEmpty) ChatMsg(last, mine: false),
          ]);
        })
        .toList(growable: false);
  }

  List<DepartmentRecord>? departments;
  if (session.collections.containsKey('departments')) {
    departments = session
        .records('departments')
        .map((row) {
          return DepartmentRecord(
            name: _text(row, const ['name', 'title']),
            manager: _text(row, const [
              'manager_name',
              'manager',
              'head_name',
              'head',
            ]),
            description: _text(row, const [
              'description',
              'notes',
            ], fallback: '—'),
            branch: _relation(row, const [
              'branch_name',
              'branch',
              'branch_id',
            ], branchNames),
            status: _text(row, const ['status', 'state'], fallback: 'active'),
            responsible: _text(row, const [
              'responsible_name',
              'responsible',
              'owner',
            ]),
            createdAt: _date(
              apiValue(row, const ['created_at', 'creation_date']),
            ),
          );
        })
        .toList(growable: false);
  }

  List<StaffMember>? staff;
  if (session.collections.containsKey('staff') ||
      session.collections.containsKey('teachers')) {
    final source = staffRows.isNotEmpty ? staffRows : teacherRows;
    staff = source
        .map((row) {
          final fullName = _text(row, const [
            'full_name',
            'name',
            'display_name',
          ]);
          final parts = fullName.split(RegExp(r'\s+'));
          return StaffMember(
            firstName: parts.isEmpty ? '—' : parts.first,
            lastName: parts.length < 2 ? '' : parts.sublist(1).join(' '),
            username: _text(row, const ['username', 'login', 'email']),
            phone: _text(row, const ['phone', 'phone_number', 'mobile']),
            email: _text(row, const ['email'], fallback: '—'),
            branch: _relation(row, const [
              'branch_name',
              'branch',
              'branch_id',
            ], branchNames),
            department: _text(row, const [
              'department_name',
              'department',
            ], fallback: '—'),
            subject: _text(row, const [
              'subject',
              'specialization',
            ], fallback: '—'),
            qualification: _text(row, const [
              'qualification',
              'position',
              'job_title',
            ], fallback: '—'),
            salaryType: _text(row, const [
              'salary_type',
              'pay_type',
            ], fallback: '—'),
            rate: _text(row, const ['salary', 'rate', 'amount'], fallback: '—'),
            gender: _text(row, const ['gender', 'sex'], fallback: '—'),
            hireDate: _date(
              apiValue(row, const ['hire_date', 'started_at', 'created_at']),
            ),
            groups: groupRows
                .where((group) {
                  final teacher = _relation(
                    group,
                    const ['teacher_name', 'teacher', 'teacher_id'],
                    teacherNames,
                    fallback: '',
                  );
                  return teacher == _id(row) || teacher == fullName;
                })
                .map((group) => _text(group, const ['name', 'title']))
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  List<ActivityEvent>? activities;
  if (session.collections.containsKey('audit')) {
    activities = session
        .records('audit')
        .map((row) {
          final kind = _text(row, const [
            'entity_type',
            'resource',
            'object_type',
          ], fallback: 'audit');
          return ActivityEvent(
            icon: switch (kind.toLowerCase()) {
              'payment' || 'payments' => Icons.payments_rounded,
              'student' || 'students' => Icons.person_outline_rounded,
              'group' || 'groups' || 'cohort' => Icons.workspaces_rounded,
              _ => Icons.policy_outlined,
            },
            title: _text(row, const ['action', 'event', 'title', 'operation']),
            detail: _text(row, const [
              'description',
              'object_repr',
              'entity_name',
              'request_id',
            ]),
            time: _time(
              apiValue(row, const ['created_at', 'timestamp', 'date']),
            ),
            kind: kind,
          );
        })
        .toList(growable: false);
  }

  store.replaceServerSnapshot(
    students: students,
    branches: branches,
    approvals: approvals,
    ledger: ledger,
    anomalies: anomalies,
    cases: cases,
    threads: threads,
    groups: groups,
    departments: departments,
    staff: staff,
    activities: activities,
  );
}
