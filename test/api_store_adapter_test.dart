import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/api_store_adapter.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
            'status': 'active',
          },
        ]
        ..collections['teachers'] = [
          {'id': 9, 'full_name': 'API Teacher', 'phone': '+998900000009'},
        ]
        ..collections['parents'] = [
          {
            'id': 11,
            'full_name': 'API Parent',
            'phone': '+998900000011',
            'student': 13,
          },
        ]
        ..collections['students'] = [
          {
            'id': 13,
            'name': 'API Student',
            'group': 7,
            'phone': '+998900000013',
            'created_at': '2026-07-01T08:00:00Z',
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
      expect(store.students.single.serverBacked, isTrue);
      final profile = studentProfile(store.students.single);
      expect(profile.phone, '+998900000013');
      expect(profile.fatherPhone, '+998900000011');
      expect(profile.motherPhone, '—');
      expect(profile.level, '—');

      expect(store.extraGroups.single.name, 'API IELTS B2');
      expect(store.extraGroups.single.teacher, 'API Teacher');
      expect(store.branches.single.name, 'API Chilonzor');
      expect(store.branches.single.students, 1);
      expect(store.branches.single.revenue, 750000);
      expect(store.ledger.single.studentName, 'API Student');
      expect(store.departments.single.name, 'API Education');
      expect(store.activities.single.title, 'student.updated');
    },
  );
}
