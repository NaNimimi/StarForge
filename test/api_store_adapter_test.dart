import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/api_store_adapter.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('live student projection never mixes or repeats backend rows', () {
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

    expect(store.students, hasLength(1));
    expect(store.students.single.name, 'Only live student');
    expect(
      store.students.any(
        (student) => student.name == 'Deleted backend student',
      ),
      isFalse,
    );
    expect(store.students.single.serverBacked, isTrue);
    expect(store.students.any((student) => !student.serverBacked), isFalse);
  });
}
