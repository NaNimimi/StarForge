import 'package:flutter_test/flutter_test.dart';
import 'package:ceo_manager/api_client.dart';
import 'package:ceo_manager/data.dart';
import 'package:ceo_manager/store.dart';

class _FailingLogoutClient extends StarforgeApiClient {
  @override
  Future<void> logout() async {
    throw const ApiException(
      status: 503,
      message: 'Revoke unavailable',
      requestId: 'logout-test',
    );
  }
}

void main() {
  group('live API relation contracts', () {
    late ApiSession session;

    setUp(() {
      session = ApiSession();
      session.collections.addAll({
        'groups': [
          {
            'id': 'g-1',
            'name': 'Algebra',
            'teacher': {'id': 't-1', 'full_name': 'Nigora Karimova'},
          },
        ],
        'teachers': [
          {'id': 't-1', 'full_name': 'Nigora Karimova'},
        ],
        'students': [
          {
            'id': 's-1',
            'full_name': 'Azizova Madina',
            'cohort_id': 'g-1',
            'attendance_rate': 90,
            'debt': 100000,
            'parent_id': 'p-1',
          },
          {
            'id': 's-2',
            'full_name': 'Halimova Zilola',
            'group': {'id': 'g-1', 'name': 'Algebra'},
            'attendance_rate': 100,
            'debt': 0,
          },
        ],
        'attendanceRecords': [
          {
            'id': 'a-1',
            'student_id': 's-1',
            'status': 'present',
            'lesson_date': '2026-07-10',
          },
          {
            'id': 'a-2',
            'student_id': 's-2',
            'status': 'absent',
            'lesson_date': '2026-06-10',
          },
        ],
        'payments': [
          {
            'id': 'pay-1',
            'student_id': 's-1',
            'amount': 600000,
            'paid_at': '2026-07-11T09:14:00Z',
            'payer_name': 'Azizov Anvar',
            'payment_method': 'Payme',
          },
        ],
        'audit': [
          {'id': 'audit-1', 'object_id': 'g-1', 'created_at': '2026-07-12'},
        ],
        'parents': [
          {'id': 'p-1', 'full_name': 'Azizov Anvar'},
        ],
        'departments': [
          {'id': 'd-1', 'name': 'English', 'status': 'active'},
          {'id': 'd-2', 'name': 'Math', 'status': 'active'},
        ],
        'staff': [
          {'id': 'e-1', 'full_name': 'Nigora Karimova', 'department_id': 'd-2'},
        ],
      });
    });

    tearDown(() => session.dispose());

    test('group snapshot joins students, history, payments, and analytics', () {
      final snapshot = session.groupSnapshot(
        session.records('groups').first,
        range: ApiDateRange(
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 7, 31),
        ),
      );

      expect(snapshot.students, hasLength(2));
      expect(snapshot.attendance.single['id'], 'a-1');
      expect(snapshot.payments.single['id'], 'pay-1');
      expect(snapshot.changes.single['id'], 'audit-1');
      expect(snapshot.analytics['student_count'], 2);
      expect(snapshot.analytics['debtor_count'], 1);
      expect(snapshot.analytics['income'], 600000);
      expect(snapshot.analytics['attendance_percent'], 100);
    });

    test('group income excludes pending, failed, and reversed payments', () {
      session.collections['payments']!.addAll([
        {
          'id': 'pay-pending',
          'student_id': 's-1',
          'amount': 900000,
          'status': 'pending',
          'paid_at': '2026-07-13T09:00:00Z',
        },
        {
          'id': 'pay-refunded',
          'student_id': 's-1',
          'amount': 800000,
          'status': 'refunded',
          'paid_at': '2026-07-14T09:00:00Z',
        },
      ]);

      final snapshot = session.groupSnapshot(
        session.records('groups').first,
        range: ApiDateRange(
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 7, 31),
        ),
      );

      expect(snapshot.payments, hasLength(3));
      expect(snapshot.analytics['income'], 600000);
      expect(apiPaymentCountsAsSettled({'status': 'failed'}), isFalse);
      expect(apiPaymentCountsAsSettled({'status': 'accepted'}), isTrue);
    });

    test('exact report range rejects undated and future records', () {
      final from = DateTime(2026, 7, 1);
      final to = DateTime(2026, 7, 23, 12);

      expect(
        apiRecordWithinInclusivePeriod(
          {'paid_at': '2026-07-01T00:00:00'},
          from: from,
          to: to,
        ),
        isTrue,
      );
      expect(
        apiRecordWithinInclusivePeriod(
          {'paid_at': '2026-07-23T12:00:01'},
          from: from,
          to: to,
        ),
        isFalse,
      );
      expect(
        apiRecordWithinInclusivePeriod({'amount': 1000}, from: from, to: to),
        isFalse,
      );
    });

    test('teacher, parent, department, and payment projections are stable', () {
      final teacher = session.records('teachers').first;
      final parent = session.records('parents').first;
      final department = session.records('departments').last;

      expect(session.groupsForTeacher(teacher), hasLength(1));
      expect(session.studentsForTeacher(teacher), hasLength(2));
      expect(session.childrenForParent(parent).single['id'], 's-1');
      expect(session.staffForDepartment(department).single['id'], 'e-1');
      expect(session.records('departments').first['id'], 'd-1');
      expect(
        session
            .records('departments')
            .every((record) => !record.containsKey('rating')),
        isTrue,
      );

      final payment = session.paymentDetails('pay-1')!;
      expect(payment.payer, 'Azizov Anvar');
      expect(payment.method, 'Payme');
      expect(payment.amount, 600000);
      expect(payment.date, '2026-07-11');
      expect(payment.time, '09:14');
    });
  });

  test('logout clears private cache even when server revoke fails', () async {
    final client = _FailingLogoutClient()..configure(token: 'session-secret');
    final session = ApiSession(client: client)
      ..collections['students'] = [
        {'id': 'private-student'},
      ]
      ..documents['financeOutstanding'] = {'amount': 10}
      ..me = {'id': 'private-user'};
    addTearDown(session.dispose);

    await expectLater(session.logout(), throwsA(isA<ApiException>()));

    expect(session.authenticated, isFalse);
    expect(session.collections, isEmpty);
    expect(session.documents, isEmpty);
    expect(session.me, isNull);
    expect(session.loading, isFalse);
  });

  group('offline store contracts', () {
    test('department and teacher additions remain backwards compatible', () {
      final store = AppStore.seed(SfRole.manager);
      addTearDown(store.dispose);

      expect(store.departments.first.name, 'Matematika');
      expect(store.staff.first.groups, contains('9-B Algebra'));
      expect(
        store.groupsForStaff(store.staff.first),
        containsAll(['9-B Algebra', 'Algebra Mid']),
      );
    });

    test('parent and group summaries use canonical students and ledger', () {
      final store = AppStore.seed(SfRole.manager);
      addTearDown(store.dispose);

      final analytics = store.analyticsForGroup('9-B Algebra');
      expect(analytics.studentCount, 4);
      expect(analytics.debtorCount, 1);
      expect(analytics.income, greaterThan(0));
      expect(store.parentSummaries, hasLength(store.students.length));

      final entry = store.ledger.first;
      expect(entry.payerName, isNotEmpty);
      expect(entry.studentName, isNotEmpty);
      expect(entry.transactionNumber, isNotEmpty);
    });

    test(
      'message reactions use stable message identity and can be removed',
      () {
        final store = AppStore.seed(SfRole.ceo);
        addTearDown(store.dispose);
        final message = store.threads.first.messages.first;

        store.setMessageReaction(message, '🔥');
        expect(store.reactionFor(message), '🔥');

        store.threads.first.messages.insert(
          0,
          ChatMsg('Earlier message', mine: false),
        );
        expect(store.reactionFor(message), '🔥');

        store.setMessageReaction(message, '🔥');
        expect(store.reactionFor(message), isNull);
      },
    );
  });
}
