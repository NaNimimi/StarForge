import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('authenticated role mapping', () {
    test(
      'maps supported backend role variants without privilege escalation',
      () {
        expect(sfRoleFromApiProfile({'role': 'ceo'}), SfRole.ceo);
        expect(
          sfRoleFromApiProfile({
            'role': {'slug': 'branch_manager', 'name': 'Branch Manager'},
          }),
          SfRole.manager,
        );
        expect(
          sfRoleFromApiProfile({'role_name': 'Compliance Auditor'}),
          SfRole.audit,
        );
        expect(sfRoleFromApiProfile({'role': 'student'}), SfRole.student);
        expect(
          sfRoleFromApiProfile({'principal_kind': 'student'}),
          SfRole.student,
        );
        expect(
          sfRoleFromApiProfile({'principal_kind': 'parent'}),
          SfRole.student,
        );
        expect(
          sfRoleFromApiProfile({
            'role': {'account_type_slug': 'guardian'},
          }),
          SfRole.student,
        );
        expect(sfRoleFromApiProfile(null), isNull);
        expect(
          sfRoleFromApiProfile({
            'username': 'admin',
            'role_memberships': [
              {
                'account_type_name': 'Director',
                'account_type_slug': 'director',
              },
            ],
          }),
          SfRole.ceo,
        );
        expect(
          sfRoleFromApiProfile({
            'role_memberships': [
              {'account_type_slug': 'manager'},
            ],
          }),
          SfRole.manager,
        );
        expect(
          sfRoleFromApiProfile({
            'role_memberships': [
              {'account_type_slug': 'head_of_dept'},
            ],
          }),
          SfRole.manager,
        );
        expect(
          sfRoleFromApiProfile({
            'role_memberships': [
              {'account_type_slug': 'auditor'},
            ],
          }),
          SfRole.audit,
        );
        expect(
          sfRoleFromApiProfile({
            'role_memberships': [
              {'account_type_slug': 'director', 'is_active': false},
            ],
          }),
          isNull,
        );
      },
    );
  });
}
