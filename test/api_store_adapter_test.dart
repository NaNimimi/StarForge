import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/api_store_adapter.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('message parser restores server edit and reaction state', () {
    final session = ApiSession()..messagingSelfUserId = 10;
    addTearDown(session.dispose);

    final message = apiChatMessage(session, {
      'id': 501,
      'sender': 10,
      'body': 'Edited message',
      'created_at': '2026-08-13T10:00:00Z',
      'edited_at': '2026-08-13T10:01:00Z',
      'my_reaction': {'emoji': '🔥'},
    });

    expect(message.serverId, '501');
    expect(message.mine, isTrue);
    expect(message.edited, isTrue);
    expect(message.reaction, '🔥');
  });

  test('reaction summary counts duplicates and marks the current user', () {
    final session = ApiSession()..messagingSelfUserId = 10;
    addTearDown(session.dispose);

    final listMessage = apiChatMessage(session, {
      'id': 502,
      'sender': 11,
      'body': 'List reactions',
      'reactions': [
        {'emoji': '👍'},
        {'emoji': '👍', 'reacted_by_me': true},
        {'emoji': '❤', 'count': 3},
      ],
    });
    final mapMessage = apiChatMessage(session, {
      'id': 503,
      'sender': 11,
      'body': 'Map reactions',
      'reaction_summary': {
        '🙏': {'count': 2, 'reacted_by_me': true},
      },
    });

    expect(listMessage.reactions, {'👍': 2, '❤': 3});
    expect(listMessage.reaction, '👍');
    expect(mapMessage.reactions, {'🙏': 2});
    expect(mapMessage.reaction, '🙏');

    final deleted = apiChatMessage(session, {
      'id': 504,
      'sender': 11,
      'body': 'Removed',
      'deleted_at': '2026-08-15T10:00:00Z',
    });
    expect(deleted.deleted, isTrue);
  });

  test('messaging identity prefers the published messaging user id', () {
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..me = {'id': 4, 'messaging_user_id': 10, 'principal_kind': 'staff'};
    addTearDown(session.dispose);

    session.updateMessagingIdentityForTest();

    expect(session.messagingSelfUserId, 10);
  });

  test('messaging snapshot keeps server identity and message ownership', () {
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..messagingSelfUserId = 15
      ..collections['threads'] = [
        {
          'id': 91,
          'subject': '',
          'participant_ids': [
            {'user': 15, 'display_name': 'Current CEO'},
            {
              'user': 14,
              'display_name': 'Madina QA Teacher',
              'role_label': 'Teacher',
              'is_online': true,
            },
          ],
          'unread_count': 2,
          'last_message': {
            'id': 301,
            'sender': 14,
            'body': 'Server message',
            'created_at': '2026-08-10T08:14:00Z',
          },
        },
      ];
    final store = AppStore.empty(SfRole.ceo);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    syncProductStoreFromApi(session, store);

    final thread = store.threads.single;
    expect(thread.meta.serverId, '91');
    expect(thread.meta.participantIds, ['15', '14']);
    expect(thread.meta.name, 'Madina QA Teacher');
    expect(thread.meta.online, isTrue);
    expect(thread.messages.single.serverId, '301');
    expect(thread.messages.single.mine, isFalse);
    expect(thread.messages.single.text, 'Server message');
  });

  test('messaging snapshot joins directory name and live presence', () {
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..messagingSelfUserId = 10
      ..messagingContacts = [
        {
          'id': 11,
          'user_id': 11,
          'display_name': 'Live Student',
          'role_label': 'Student',
          'is_online': true,
          'profile': {
            'identity': {
              'photo': {
                'available': true,
                'download_url': 'https://storage.example/student-11.jpg',
              },
            },
          },
        },
      ]
      ..collections['threads'] = [
        {
          'id': 92,
          'subject': 'Fallback subject',
          'participants': [
            {'user': 10, 'principal_kind': 'staff'},
            {'user': 11, 'principal_kind': 'student'},
          ],
        },
      ];
    final store = AppStore.empty(SfRole.ceo);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    syncProductStoreFromApi(session, store);

    expect(store.threads.single.meta.name, 'Live Student');
    expect(store.threads.single.meta.online, isTrue);
    expect(
      store.threads.single.meta.avatarUrl,
      'https://storage.example/student-11.jpg',
    );
  });

  test('audit activity is newest-first and keeps backend context', () {
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..collections['audit'] = [
        {
          'id': 1,
          'actor_username': 'manager',
          'action': 'update',
          'resource_type': 'academics.Student',
          'resource_id': '42',
          'created_at': '2026-08-18T07:00:00Z',
        },
        {
          'id': 2,
          'actor_username': 'ceo',
          'action': 'login',
          'resource_type': 'users.User',
          'resource_id': '10',
          'created_at': '2026-08-18T08:00:00Z',
        },
      ];
    final store = AppStore.empty(SfRole.ceo);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    syncProductStoreFromApi(session, store);

    expect(store.activities.map((event) => event.title), ['login', 'update']);
    expect(store.activities.first.detail, 'ceo · users.User #10');
    expect(store.activities.last.detail, 'manager · academics.Student #42');
  });

  test('direct chat identity never comes from a technical subject', () {
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..messagingSelfUserId = 10
      ..messagingContacts = [
        {
          'id': 11,
          'user_id': 11,
          'principal_kind': 'student',
          'display_name': 'Aziz Rustam o‘g‘li Karimov',
          'username': 'qa.student.20260804',
          'role_label': 'Student',
          'is_online': false,
          'is_online_is_heuristic': true,
          'recently_active': false,
        },
      ]
      ..collections['threads'] = [
        {
          'id': 1209,
          'subject': 'Chat verification',
          'participants': [
            {'user': 10, 'principal_kind': 'staff'},
            {
              'user': 11,
              'principal_kind': 'student',
              'display_name': 'Chat verification',
              'role_label': 'Chat verification',
            },
          ],
        },
      ];
    final store = AppStore.empty(SfRole.ceo);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    syncProductStoreFromApi(session, store);

    expect(store.threads.single.meta.name, 'Aziz Rustam o‘g‘li Karimov');
    expect(store.threads.single.meta.group, 'Student');
    expect(store.threads.single.meta.online, isFalse);
  });

  test(
    'direct chat without a directory contact does not expose its subject',
    () {
      final client = StarforgeApiClient()..configure(token: 'test-session');
      final session = ApiSession(client: client)
        ..messagingSelfUserId = 10
        ..collections['threads'] = [
          {
            'id': 1209,
            'subject': 'Chat verification',
            'participants': [
              {'user': 10, 'principal_kind': 'staff'},
              {'user': 11, 'principal_kind': 'student'},
            ],
          },
        ];
      final store = AppStore.empty(SfRole.ceo);
      addTearDown(session.dispose);
      addTearDown(store.dispose);

      syncProductStoreFromApi(session, store);

      expect(store.threads.single.meta.name, 'Ученик');
      expect(store.threads.single.meta.name, isNot('Chat verification'));
    },
  );

  test(
    'authenticated API snapshot feeds product models without demo values',
    () {
      final client = StarforgeApiClient()..configure(token: 'test-session');
      final session = ApiSession(client: client)
        ..collections['branches'] = [
          {'id': 5, 'name': 'API Chilonzor', 'is_active': true},
        ]
        ..collections['groups'] = [
          {
            'id': 7,
            'name': 'API IELTS B2',
            'branch': 5,
            'teacher': 9,
            'primary_teacher_name': 'Primary API Teacher',
            'status': 'active',
          },
        ]
        ..collections['teachers'] = [
          {'id': 9, 'full_name': 'API Teacher', 'phone': '+998900000009'},
        ]
        ..collections['parents'] = [
          {'id': 11, 'full_name': 'API Parent', 'phone': '+998900000011'},
        ]
        ..collections['guardians'] = [
          {
            'id': 12,
            'parent': 11,
            'parent_name': 'API Parent',
            'student': 13,
            'student_name': 'API Student',
            'relationship': 'father',
            'is_primary': true,
          },
          {
            'id': 14,
            'parent': 15,
            'parent_name': 'Secondary Parent',
            'student': 13,
            'student_name': 'API Student',
            'relationship': 'other',
            'is_primary': false,
          },
        ]
        ..collections['students'] = [
          {
            'id': 13,
            'student_id': 'SF-PUBLIC-13',
            'name': 'API Student',
            'current_cohort': 7,
            'academic_level': 'B2',
            'phone': '+998900000013',
            'user': {'id': 113, 'username': 'api-student'},
            'enrollment_date': '2026-07-01T08:00:00Z',
            'is_active': true,
          },
        ]
        ..collections['payments'] = [
          {
            'id': 17,
            'student': 13,
            'group': 7,
            'branch': 5,
            'amount': 750000,
            'status': 'paid',
            'created_at': '2026-07-30T09:14:00Z',
          },
        ]
        ..collections['departments'] = [
          {
            'id': 19,
            'name': 'API Education',
            'branch': 5,
            'manager_name': 'API Head',
            'status': 'active',
          },
        ]
        ..collections['audit'] = [
          {
            'id': 21,
            'action': 'student.updated',
            'entity_type': 'student',
            'created_at': '2026-07-31T10:00:00Z',
          },
        ];
      final store = AppStore.empty(SfRole.ceo);
      addTearDown(session.dispose);
      addTearDown(store.dispose);

      syncProductStoreFromApi(session, store);

      expect(store.students.single.name, 'API Student');
      expect(store.students.single.group, 'API IELTS B2');
      expect(store.students.single.branch, 'API Chilonzor');
      expect(store.students.single.parentName, 'API Parent');
      expect(store.students.single.studentNumber, 'SF-PUBLIC-13');
      expect(store.students.single.serverUserId, '113');
      expect(store.students.single.teacher, 'Primary API Teacher');
      expect(store.students.single.serverBacked, isTrue);
      final profile = studentProfile(store.students.single);
      expect(profile.phone, '+998900000013');
      expect(profile.fatherPhone, '+998900000011');
      expect(profile.enrolled, '01.07.2026');
      expect(profile.motherPhone, '—');
      expect(profile.level, 'B2');

      expect(store.extraGroups.single.name, 'API IELTS B2');
      expect(store.extraGroups.single.teacher, 'Primary API Teacher');
      expect(store.branches.single.name, 'API Chilonzor');
      expect(store.branches.single.students, 1);
      expect(store.branches.single.revenue, 750000);
      expect(store.ledger.single.studentName, 'API Student');
      expect(store.departments.single.name, 'API Education');
      expect(store.activities.single.title, 'student.updated');
      expect(
        session
            .childrenForParent(session.records('parents').single)
            .single['id'],
        13,
      );
    },
  );

  test('live student projection preserves every unique backend row', () {
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..collections['students'] = [
        {'id': 44, 'name': 'Only live student'},
        {'id': 44, 'name': 'Only live student'},
        {'id': 45, 'name': 'Deleted backend student', 'is_active': false},
      ];
    final store = AppStore.seed(SfRole.ceo);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    syncProductStoreFromApi(session, store);

    expect(store.students, hasLength(2));
    expect(
      store.students.map((student) => student.name),
      containsAll(['Only live student', 'Deleted backend student']),
    );
    expect(
      store.students
          .singleWhere((student) => student.name == 'Deleted backend student')
          .pay,
      'left',
    );
    expect(
      store.students.where((student) => student.name == 'Only live student'),
      hasLength(1),
    );
    final unknown = store.students.singleWhere(
      (student) => student.name == 'Only live student',
    );
    expect(unknown.attendanceKnown, isFalse);
    expect(unknown.debtKnown, isFalse);
    expect(unknown.pay, 'unknown');
    expect(store.students.any((student) => !student.serverBacked), isFalse);
  });

  test('staff branch and department come from live role memberships', () {
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..collections['branches'] = [
        {'id': 5, 'name': 'Membership Branch'},
      ]
      ..collections['departments'] = [
        {'id': 8, 'name': 'Membership Department'},
      ]
      ..collections['staff'] = [
        {
          'id': 17,
          'username': 'membership.staff',
          'full_name': 'Membership Staff',
          'role_memberships': [
            {
              'id': 91,
              'branch': 5,
              'branch_name': 'Membership Branch',
              'department': 8,
              'department_name': 'Membership Department',
            },
          ],
        },
      ];
    final store = AppStore.empty(SfRole.ceo);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    syncProductStoreFromApi(session, store);

    expect(store.staff.single.branch, 'Membership Branch');
    expect(store.staff.single.department, 'Membership Department');
    expect(
      session.staffForDepartment(session.records('departments').single),
      hasLength(1),
    );
  });

  test('manager directory keeps staff and teachers with overlapping ids', () {
    final client = StarforgeApiClient()..configure(token: 'test-session');
    final session = ApiSession(client: client)
      ..collections['staff'] = [
        {'id': 2, 'username': 'branch.manager', 'full_name': 'Branch Manager'},
      ]
      ..collections['teachers'] = [
        {
          'id': 2,
          'username': 'bodring',
          'full_name': 'Bodring Bording Bording',
        },
      ];
    final store = AppStore.empty(SfRole.manager);
    addTearDown(session.dispose);
    addTearDown(store.dispose);

    syncProductStoreFromApi(session, store);

    expect(store.staff, hasLength(2));
    expect(
      store.staff.map((member) => member.username),
      containsAll(<String>['branch.manager', 'bodring']),
    );
  });
}
