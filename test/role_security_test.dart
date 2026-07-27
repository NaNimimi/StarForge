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
        expect(sfRoleFromApiProfile({'role': 'student'}), isNull);
        expect(sfRoleFromApiProfile(null), isNull);
      },
    );
  });
}
