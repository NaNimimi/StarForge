import 'dart:convert';

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

/// Defensive identity pass at the product-model boundary. Normally
/// [StarforgeApiClient.list] already canonicalises complete collections, but
/// keeping the adapter strict also protects restored/test snapshots and
/// endpoint variants that happen to repeat a row in one response.
List<_Row> _uniqueRows(Iterable<_Row> rows) {
  final identities = <String>{};
  final result = <_Row>[];
  for (final row in rows) {
    final id = _id(row);
    final key = id.isEmpty ? jsonEncode(row) : id.toLowerCase();
    if (identities.add(key)) result.add(row);
  }
  return result;
}

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

Map<String, dynamic>? _primaryRoleMembership(_Row row) {
  final value = apiValue(row, const [
    'role_memberships',
    'memberships',
    'account_type_assignments',
  ]);
  if (value is! Iterable || value is String) return null;
  final memberships = value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
  if (memberships.isEmpty) return null;
  bool marked(Map<String, dynamic> membership) => _truthy(
    apiValue(membership, const ['is_primary', 'primary', 'is_current']),
  );
  for (final membership in memberships) {
    if (marked(membership)) return membership;
  }
  for (final membership in memberships) {
    final kind = _text(membership, const [
      'account_kind',
      'principal_kind',
      'kind',
    ], fallback: '').toLowerCase();
    if (kind == 'staff') return membership;
  }
  return memberships.first;
}

String _staffMembershipRelation(
  _Row row,
  Iterable<String> directKeys,
  Iterable<String> membershipKeys,
  Map<String, String> names, {
  String fallback = '—',
}) {
  final direct = apiValue(row, directKeys);
  if (direct != null && apiText(direct).isNotEmpty) {
    return _relation(row, directKeys, names, fallback: fallback);
  }
  final membership = _primaryRoleMembership(row);
  if (membership == null) return fallback;
  return _relation(membership, membershipKeys, names, fallback: fallback);
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
  final local = parsed.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

List<String> _stringList(Object? value) {
  if (value is! Iterable || value is String) return const [];
  return value
      .map((item) {
        if (item is Map) {
          final row = Map<String, dynamic>.from(item);
          return apiText(apiValue(row, const ['user', 'user_id', 'id', 'pk']));
        }
        return apiText(item);
      })
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _userId(Object? value) {
  if (value is Map) {
    final row = Map<String, dynamic>.from(value);
    return apiText(
      apiValue(row, const ['user_id', 'account_id', 'user', 'id', 'pk']),
    );
  }
  return apiText(value);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! Iterable || value is String) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _attachmentKeys(Object? value) {
  if (value is! Iterable || value is String) return const [];
  return value
      .map((item) {
        if (item is Map) {
          return apiText(
            apiValue(Map<String, dynamic>.from(item), const [
              'key',
              'storage_key',
              'path',
              'url',
            ]),
          );
        }
        return apiText(item);
      })
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _avatarUrl(ApiSession session, Map<String, dynamic> row) {
  Object? findAvatar(Object? value, [int depth = 0]) {
    if (depth > 4 || value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final direct = apiValue(map, const [
      'avatar_url',
      'profile_photo_url',
      'photo_url',
      'image_url',
      'avatar',
      'profile_photo',
      'photo',
      'image',
    ]);
    if (direct != null) return direct;
    for (final key in const ['identity', 'profile', 'student', 'contact']) {
      final nested = findAvatar(map[key], depth + 1);
      if (nested != null) return nested;
    }
    return null;
  }

  Object? raw = findAvatar(row);
  if (raw is Map) {
    raw = apiValue(Map<String, dynamic>.from(raw), const [
      'url',
      'download_url',
      'file_url',
      'path',
    ]);
  }
  final value = apiText(raw).trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.hasAuthority) return value;
  if (!value.startsWith('/')) return null;
  return '${session.client.baseUrl}$value';
}

ChatMessageKind _messageKind(List<String> attachments) {
  if (attachments.isEmpty) return ChatMessageKind.text;
  final value = attachments.first.toLowerCase().split('?').first;
  if (RegExp(r'\.(mp4|mov|m4v|webm|avi)$').hasMatch(value)) {
    return ChatMessageKind.video;
  }
  if (RegExp(r'\.(m4a|aac|mp3|ogg|wav|opus)$').hasMatch(value)) {
    return ChatMessageKind.voice;
  }
  if (RegExp(r'\.(jpg|jpeg|png|gif|webp|heic)$').hasMatch(value)) {
    return ChatMessageKind.image;
  }
  return ChatMessageKind.text;
}

Map<String, int> _reactionCounts(Object? value) {
  final result = <String, int>{};
  if (value is Map) {
    for (final entry in value.entries) {
      final emoji = '${entry.key}'.trim();
      final raw = entry.value is Map
          ? apiValue(Map<String, dynamic>.from(entry.value as Map), const [
              'count',
              'total',
            ])
          : entry.value;
      final count = int.tryParse('$raw') ?? 0;
      if (emoji.isNotEmpty && count > 0) result[emoji] = count;
    }
  } else if (value is Iterable && value is! String) {
    for (final item in value) {
      if (item is Map) {
        final row = Map<String, dynamic>.from(item);
        final emoji = apiText(apiValue(row, const ['emoji', 'value']));
        final count =
            int.tryParse(
              apiText(apiValue(row, const ['count', 'total']), fallback: '1'),
            ) ??
            1;
        if (emoji.isNotEmpty && count > 0) {
          result[emoji] = (result[emoji] ?? 0) + count;
        }
      } else {
        final emoji = apiText(item);
        if (emoji.isNotEmpty) result[emoji] = (result[emoji] ?? 0) + 1;
      }
    }
  }
  return result;
}

/// Converts the published message DTO into the established conversation
/// model. Ownership comes from `self_user_id`; it is never guessed from the
/// message order or populated with generated sample replies.
ChatMsg apiChatMessage(ApiSession session, Map<String, dynamic> row) {
  final rawSender = apiValue(row, const ['sender', 'sender_id', 'user']);
  final senderId = rawSender is Map
      ? apiText(
          apiValue(Map<String, dynamic>.from(rawSender), const [
            'id',
            'pk',
            'user_id',
          ]),
        )
      : apiText(rawSender);
  final explicitMine = apiValue(row, const ['is_mine', 'mine']);
  final mine = explicitMine is bool
      ? explicitMine
      : senderId.isNotEmpty &&
            senderId == '${session.messagingSelfUserId ?? ''}';
  final attachments = _attachmentKeys(
    apiValue(row, const ['attachments', 'attachment_keys', 'files']),
  );
  final rawReaction = apiValue(row, const [
    'my_reaction',
    'reaction',
    'selected_reaction',
  ]);
  String? reaction;
  if (rawReaction is Map) {
    reaction = apiText(
      apiValue(Map<String, dynamic>.from(rawReaction), const [
        'emoji',
        'value',
      ]),
    );
  } else {
    reaction = apiText(rawReaction);
  }
  final rawReactions = apiValue(row, const ['reactions', 'reaction_summary']);
  if (reaction.isEmpty) {
    if (rawReactions is Map) {
      for (final entry in rawReactions.entries) {
        if (entry.value is! Map) continue;
        final candidate = Map<String, dynamic>.from(entry.value as Map);
        if (apiValue(candidate, const ['reacted_by_me', 'is_mine', 'mine']) ==
            true) {
          reaction = apiText(
            apiValue(candidate, const ['emoji', 'value']),
            fallback: '${entry.key}',
          );
          break;
        }
      }
    } else if (rawReactions is Iterable && rawReactions.isNotEmpty) {
      for (final item in rawReactions) {
        if (item is! Map) continue;
        final candidate = Map<String, dynamic>.from(item);
        if (apiValue(candidate, const ['reacted_by_me', 'is_mine', 'mine']) ==
            true) {
          reaction = apiText(apiValue(candidate, const ['emoji', 'value']));
          break;
        }
      }
    }
  }
  final reactionCounts = _reactionCounts(rawReactions);
  final currentReaction = reaction ?? '';
  if (currentReaction.isNotEmpty &&
      !reactionCounts.containsKey(currentReaction)) {
    reactionCounts[currentReaction] = 1;
  }
  final rawAttachment = apiValue(row, const [
    'attachments',
    'attachment_keys',
    'files',
  ]);
  final firstAttachment = rawAttachment is Iterable && rawAttachment.isNotEmpty
      ? rawAttachment.first
      : null;
  final attachmentMap = firstAttachment is Map
      ? Map<String, dynamic>.from(firstAttachment)
      : const <String, dynamic>{};
  final durationMs = int.tryParse(
    apiText(
      apiValue(attachmentMap, const ['duration_ms', 'duration_milliseconds']),
    ),
  );
  final durationSeconds = double.tryParse(
    apiText(apiValue(attachmentMap, const ['duration_seconds', 'duration'])),
  );
  final createdAt = apiDate(
    apiValue(row, const ['created_at', 'sent_at', 'date']),
  );
  final editedAt = apiDate(
    apiValue(row, const ['edited_at', 'modified_at', 'updated_at']),
  );
  final explicitEdited = apiValue(row, const ['is_edited', 'edited']);
  final edited = explicitEdited is bool
      ? explicitEdited
      : editedAt != null &&
            (createdAt == null ||
                editedAt.difference(createdAt).abs() >
                    const Duration(seconds: 1));
  final deleted =
      apiValue(row, const ['is_deleted', 'deleted']) == true ||
      apiValue(row, const ['deleted_at', 'removed_at']) != null;
  return ChatMsg(
    _text(row, const ['body', 'text', 'content', 'message'], fallback: ''),
    mine: mine,
    kind: _messageKind(attachments),
    serverId: _id(row),
    createdAt: createdAt,
    duration: durationMs != null
        ? Duration(milliseconds: durationMs)
        : durationSeconds != null
        ? Duration(milliseconds: (durationSeconds * 1000).round())
        : null,
    attachmentKeys: attachments,
    reaction: currentReaction.isEmpty ? null : currentReaction,
    reactions: reactionCounts,
    mimeType:
        apiText(
          apiValue(attachmentMap, const ['content_type', 'mime_type', 'mime']),
        ).trim().isEmpty
        ? null
        : apiText(
            apiValue(attachmentMap, const [
              'content_type',
              'mime_type',
              'mime',
            ]),
          ),
    sizeBytes: int.tryParse(
      apiText(apiValue(attachmentMap, const ['size_bytes', 'size'])),
    ),
    edited: edited,
    deleted: deleted,
  );
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
  final studentRows = _uniqueRows(session.records('students'));
  final parentRows = session.records('parents');
  final guardianRows = session.records('guardians');
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
  final primaryGuardianKeys = <String>{};
  final parentById = <String, _Row>{
    for (final row in parentRows)
      if (_id(row).isNotEmpty) _id(row): row,
  };
  // Keep compatibility with older API variants that embedded the child on
  // the parent record itself.
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
  // The current backend publishes the relationship separately through
  // /parents/guardians/. Join it here so both the student and parent product
  // pages receive the actual contact from the database.
  for (final link in guardianRows) {
    final rawParent = apiValue(link, const [
      'parent',
      'parent_id',
      'guardian',
      'guardian_id',
    ]);
    final parentId = rawParent is Map
        ? apiText(
            apiValue(Map<String, dynamic>.from(rawParent), const ['id', 'pk']),
          )
        : apiText(rawParent);
    final parent = parentById[parentId];
    final joined = <String, dynamic>{
      ...?parent,
      if (parent == null) ...link,
      if (apiText(
        apiValue(parent ?? const {}, const ['full_name', 'name']),
      ).isEmpty)
        'full_name': _text(link, const ['parent_name', 'guardian_name']),
    };
    final rawStudent = apiValue(link, const [
      'student',
      'student_id',
      'child',
      'child_id',
    ]);
    final studentId = rawStudent is Map
        ? apiText(
            apiValue(Map<String, dynamic>.from(rawStudent), const [
              'id',
              'pk',
              'student_id',
            ]),
          )
        : apiText(rawStudent);
    final studentName = _text(link, const [
      'student_name',
      'child_name',
    ], fallback: '');
    final isPrimary = _truthy(link['is_primary']);
    void assign(String key) {
      if (key.isEmpty) return;
      if (primaryGuardianKeys.contains(key)) return;
      if (parentByStudent.containsKey(key) && !isPrimary) return;
      parentByStudent[key] = joined;
      if (isPrimary) primaryGuardianKeys.add(key);
    }

    assign(studentId);
    assign(studentName);
  }

  List<Student>? students;
  if (session.collections.containsKey('students')) {
    students = studentRows
        .map((row) {
          final id = _id(row);
          final groupValue = apiText(
            apiValue(row, const [
              'group_id',
              'group',
              'cohort_id',
              'cohort',
              'current_cohort',
            ]),
          );
          final group = groupById[groupValue];
          final groupName = group == null
              ? _relation(row, const [
                  'group_name',
                  'group',
                  'cohort_name',
                  'cohort',
                  'current_cohort',
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
          final debtValue = apiNumber(row, const [
            'debt_uzs',
            'debt',
            'debt_amount',
            'outstanding_amount',
            'balance_due',
          ]);
          final debt = debtValue ?? 0;
          final active = apiValue(row, const ['is_active', 'active']);
          final rawStatus = _text(row, const [
            'payment_status',
            'pay_status',
          ], fallback: '').toLowerCase();
          final lifecycle = _text(row, const [
            'status',
            'student_status',
          ], fallback: '').toLowerCase();
          final hasExited = const {
            'withdrawn',
            'graduated',
            'left',
            'archived',
            'inactive',
          }.contains(lifecycle);
          final lifecycleStatus =
              hasExited || active != null && !_truthy(active)
              ? (lifecycle.isEmpty ? 'inactive' : lifecycle)
              : lifecycle.isEmpty
              ? 'active'
              : lifecycle;
          final paymentState = hasExited || active != null && !_truthy(active)
              ? 'left'
              : rawStatus.contains('partial')
              ? 'partial'
              : rawStatus.contains('debt') || rawStatus.contains('overdue')
              ? 'debt'
              : rawStatus.contains('paid')
              ? 'paid'
              : debtValue == null
              ? 'unknown'
              : debt > 0
              ? 'debt'
              : 'paid';
          final parent =
              parentByStudent[id] ??
              parentByStudent[_text(row, const ['name', 'full_name'])];
          final account = apiValue(row, const ['user', 'account']);
          final accountRow = account is Map
              ? Map<String, dynamic>.from(account)
              : const <String, dynamic>{};
          return Student(
            _text(row, const ['full_name', 'name', 'student_name']),
            groupName,
            _percentage(attendance ?? 0),
            paymentState,
            debt,
            attendanceKnown: attendance != null,
            debtKnown: debtValue != null || rawStatus.isNotEmpty,
            lifecycleStatus: lifecycleStatus,
            rating: apiNumber(row, const [
              'rating',
              'student_rating',
              'academic_rating',
            ])?.toDouble(),
            averageScore: apiNumber(row, const [
              'average_score',
              'average_grade',
              'score_average',
            ])?.round(),
            studentNumber: _text(row, const [
              'student_id',
              'id',
              'pk',
            ], fallback: id),
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
            username: _text(
              row,
              const ['username', 'login', 'email'],
              fallback: _text(accountRow, const [
                'username',
                'login',
                'phone',
                'email',
              ], fallback: '—'),
            ),
            gender: _text(row, const ['gender', 'sex'], fallback: '—'),
            level: _text(
              row,
              const ['academic_level', 'level_name', 'level', 'course_level'],
              fallback: group == null
                  ? '—'
                  : _text(group, const ['level_name', 'level'], fallback: '—'),
            ),
            teacher: group == null
                ? _text(row, const [
                    'primary_teacher_name',
                    'teacher_name',
                  ], fallback: '—')
                : _text(group, const [
                    'primary_teacher_name',
                    'teacher_name',
                    'teacher',
                  ], fallback: '—'),
            enrolledAt: _date(
              apiValue(row, const [
                'enrollment_date',
                'enrolled_at',
                'start_date',
                'created_at',
              ]),
            ),
            age: apiNumber(row, const ['age'])?.round(),
            avatarUrl:
                _avatarUrl(session, row) ??
                (accountRow.isEmpty ? null : _avatarUrl(session, accountRow)),
            serverId: id,
            serverUserId: _userId(
              apiValue(row, const ['user_id', 'account_id', 'user', 'account']),
            ),
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
              'primary_teacher_name',
              'primary_teacher',
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
            serverId: id,
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
          final rawLast = apiValue(row, const [
            'last_message',
            'message',
            'preview',
          ]);
          final lastRow = rawLast is Map
              ? Map<String, dynamic>.from(rawLast)
              : null;
          final last = lastRow == null
              ? apiText(rawLast, fallback: '')
              : _text(lastRow, const [
                  'body',
                  'text',
                  'content',
                  'message',
                ], fallback: '');
          final rawParticipants = apiValue(row, const [
            'participants',
            'participant_ids',
            'members',
            'member_ids',
          ]);
          final participantIds = _stringList(rawParticipants);
          final selfId = '${session.messagingSelfUserId ?? ''}';
          final otherIds = participantIds
              .where((id) => selfId.isEmpty || id != selfId)
              .toList(growable: false);
          Map<String, dynamic>? participant;
          for (final candidate in _mapList(rawParticipants)) {
            if (otherIds.contains(_userId(candidate))) {
              participant = candidate;
              break;
            }
          }
          if (otherIds.isNotEmpty) {
            Map<String, dynamic>? directoryContact;
            for (final candidate in session.messagingContacts) {
              final candidateId = apiText(
                apiValue(candidate, const ['user_id', 'user', 'id', 'pk']),
              );
              if (otherIds.contains(candidateId)) {
                directoryContact = candidate;
                break;
              }
            }
            if (directoryContact != null) {
              participant = <String, dynamic>{
                ...?participant,
                // The directory is the identity authority. Thread
                // participants intentionally contain only bridge ids and a
                // principal kind on the live API; older deployments could
                // also repeat a technical subject as a display label.
                ...directoryContact,
              };
            }
          }
          final directName = participant == null
              ? ''
              : _text(participant, const [
                  'display_name',
                  'full_name',
                  'name',
                  'username',
                ], fallback: '');
          final subject = _text(row, const [
            'subject',
            'name',
            'title',
          ], fallback: '');
          final isGroup =
              _truthy(apiValue(row, const ['is_group', 'group_chat'])) ||
              otherIds.length > 1;
          final principalKind = participant == null
              ? ''
              : _text(participant, const [
                  'principal_kind',
                  'category',
                  'role_slug',
                ], fallback: '').toLowerCase();
          final publishedRole = participant == null
              ? ''
              : _text(participant, const ['role_label', 'role'], fallback: '');
          final contactRole = switch (principalKind) {
            'student' => 'Student',
            'parent' || 'guardian' => 'Parent',
            'teacher' => 'Teacher',
            _ => publishedRole.isNotEmpty ? publishedRole : principalKind,
          };
          final directFallback = switch (principalKind) {
            'student' => 'Ученик',
            'parent' || 'guardian' => 'Родитель',
            'teacher' => 'Преподаватель',
            _ => 'Диалог',
          };
          // A direct-thread subject is descriptive metadata, not a person's
          // identity (the live thread 1209, for example, is called
          // "Chat verification"). Use it only for real group conversations.
          final title = isGroup
              ? (subject.isNotEmpty ? subject : 'Групповой чат')
              : directName.isNotEmpty
              ? directName
              : directFallback;
          final lastSeenAt = apiDate(
            apiValue(participant ?? row, const [
              'last_seen_at',
              'last_seen',
              'last_active_at',
              'last_login_at',
            ]),
          );
          final explicitOnline = apiValue(participant ?? row, const [
            'online',
            'is_online',
          ]);
          final meta = Thread(
            title,
            isGroup
                ? 'Группа · ${otherIds.length + (selfId.isEmpty ? 0 : 1)}'
                : contactRole.isEmpty
                ? 'Диалог'
                : contactRole,
            last,
            _time(
              apiValue(lastRow ?? row, const [
                'created_at',
                'updated_at',
                'last_message_at',
              ]),
            ),
            unread: _integer(row, const ['unread_count', 'unread']),
            online: explicitOnline == null
                ? chatPresenceIsOnline(lastSeenAt)
                : _truthy(explicitOnline),
            lastSeenAt: lastSeenAt,
            isGroup: isGroup,
            serverId: _id(row),
            participantIds: participantIds,
            avatarUrl: participant == null
                ? null
                : _avatarUrl(session, participant),
          );
          return ChatThread(meta, [
            if (lastRow != null) apiChatMessage(session, lastRow),
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
    // Staff and teachers are separate profile namespaces on the live API.
    // Keeping only the non-empty staff collection made real teachers vanish
    // from Manager screens even though they remained present in messaging
    // contacts. Merge both directories and deduplicate the same account by
    // username (profile ids can legitimately overlap across namespaces).
    final source = <_Row>[];
    final seenAccounts = <String>{};
    for (final row in [...teacherRows, ...staffRows]) {
      final account = apiValue(row, const ['user', 'account']);
      final accountRow = account is Map
          ? Map<String, dynamic>.from(account)
          : const <String, dynamic>{};
      final username = _text(
        row,
        const ['username', 'login', 'email'],
        fallback: _text(accountRow, const [
          'username',
          'login',
          'phone',
          'email',
        ], fallback: ''),
      ).trim().toLowerCase();
      final fullName = _text(
        row,
        const ['full_name', 'name', 'display_name'],
        fallback: _text(accountRow, const [
          'full_name',
          'name',
          'display_name',
        ], fallback: ''),
      ).trim().toLowerCase();
      final identity = username.isNotEmpty
          ? 'username:$username'
          : fullName.isNotEmpty
          ? 'name:$fullName'
          : 'record:${jsonEncode(row)}';
      if (seenAccounts.add(identity)) source.add(row);
    }
    staff = source
        .map((row) {
          final account = apiValue(row, const ['user', 'account']);
          final accountRow = account is Map
              ? Map<String, dynamic>.from(account)
              : const <String, dynamic>{};
          final fullName = _text(
            row,
            const ['full_name', 'name', 'display_name'],
            fallback: _text(accountRow, const [
              'full_name',
              'name',
              'display_name',
            ]),
          );
          final parts = fullName.split(RegExp(r'\s+'));
          return StaffMember(
            firstName: parts.isEmpty ? '—' : parts.first,
            lastName: parts.length < 2 ? '' : parts.sublist(1).join(' '),
            username: _text(
              row,
              const ['username', 'login', 'email'],
              fallback: _text(accountRow, const [
                'username',
                'login',
                'phone',
                'email',
              ]),
            ),
            phone: _text(
              row,
              const ['phone', 'phone_number', 'mobile'],
              fallback: _text(accountRow, const [
                'phone',
                'phone_number',
                'mobile',
              ]),
            ),
            email: _text(row, const [
              'email',
            ], fallback: _text(accountRow, const ['email'], fallback: '—')),
            branch: _staffMembershipRelation(
              row,
              const ['branch_name', 'branch', 'branch_id'],
              const ['branch_name', 'branch', 'branch_id'],
              branchNames,
            ),
            department: _staffMembershipRelation(
              row,
              const ['department_name', 'department', 'department_id'],
              const ['department_name', 'department', 'department_id'],
              const <String, String>{},
            ),
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
            serverId: _id(row),
          );
        })
        .toList(growable: false);
  }

  List<ActivityEvent>? activities;
  if (session.collections.containsKey('audit')) {
    final auditRows = [...session.records('audit')]
      ..sort((left, right) {
        final leftAt = apiRecordDate(left);
        final rightAt = apiRecordDate(right);
        if (leftAt == null && rightAt == null) return 0;
        if (leftAt == null) return 1;
        if (rightAt == null) return -1;
        return rightAt.compareTo(leftAt);
      });
    activities = auditRows
        .map((row) {
          final kind = _text(row, const [
            'entity_type',
            'resource',
            'object_type',
            'resource_type',
          ], fallback: 'audit');
          final actor = _text(row, const [
            'actor_username',
            'actor_name',
            'username',
            'actor_repr',
          ], fallback: '');
          final resourceId = _text(row, const [
            'resource_id',
            'entity_id',
            'object_id',
          ], fallback: '');
          final scope = apiValue(row, const ['scope']);
          final scopeRow = scope is Map
              ? Map<String, dynamic>.from(scope)
              : const <String, dynamic>{};
          final branch = apiText(
            apiValue(scopeRow, const ['branch', 'branch_name']),
          );
          final publishedDetail = _text(row, const [
            'description',
            'object_repr',
            'entity_name',
          ], fallback: '');
          final generatedDetail = [
            if (actor.isNotEmpty) actor,
            if (kind.isNotEmpty)
              resourceId.isEmpty ? kind : '$kind #$resourceId',
            if (branch.isNotEmpty) branch,
          ].join(' · ');
          return ActivityEvent(
            icon: switch (kind.toLowerCase()) {
              'payment' || 'payments' => Icons.payments_rounded,
              'student' || 'students' => Icons.person_outline_rounded,
              'group' || 'groups' || 'cohort' => Icons.workspaces_rounded,
              'users.user' || 'user' || 'users' => Icons.person_rounded,
              _ => Icons.policy_outlined,
            },
            title: _text(row, const ['action', 'event', 'title', 'operation']),
            detail: publishedDetail.isNotEmpty
                ? publishedDetail
                : generatedDetail,
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
