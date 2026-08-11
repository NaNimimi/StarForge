import 'package:ceo_manager/notification_service.dart';
import 'package:ceo_manager/push_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase runtime configuration', () {
    test('requires every Firebase identity field', () {
      expect(
        firebaseOptionsFromValues(
          apiKey: 'api-key',
          appId: '',
          messagingSenderId: 'sender',
          projectId: 'project',
        ),
        isNull,
      );
    });

    test('builds options without persisting secrets', () {
      final options = firebaseOptionsFromValues(
        apiKey: 'api-key',
        appId: '1:123:android:abc',
        messagingSenderId: '123',
        projectId: 'starforge-prod',
        storageBucket: 'starforge-prod.firebasestorage.app',
      );

      expect(options, isNotNull);
      expect(options?.appId, '1:123:android:abc');
      expect(options?.messagingSenderId, '123');
      expect(options?.projectId, 'starforge-prod');
    });
  });

  test('device registration matches the published devices endpoint model', () {
    expect(
      pushDeviceRegistrationBody(
        deviceId: 'sf_installation_1',
        platform: pushPlatformName(TargetPlatform.android),
        token: 'fcm-token',
      ),
      {
        'device_id': 'sf_installation_1',
        'platform': 'android',
        'push_token': 'fcm-token',
        'user_agent': 'StarForge EDU android',
      },
    );
  });

  group('notification deep links', () {
    test('normalizes API paths and singular aliases', () {
      expect(
        notificationRouteFromPayload({
          'target': '/api/v1/payments/42/?from=push',
        }),
        'payments',
      );
      expect(notificationRouteFromPayload({'screen': 'student'}), 'students');
    });

    test('falls back to the notification inbox', () {
      expect(notificationRouteFromPayload(const {}), 'notifications');
    });

    test('message payload opens chats when the backend sends a thread id', () {
      expect(
        notificationRouteFromPayload({
          'thread_id': 'thread-42',
          'message_id': 'message-9',
          'route': 'notifications',
        }),
        'messages',
      );
    });

    test('decodes JSON and legacy route payloads', () {
      expect(decodeNotificationPayload('{"route":"groups","id":7}'), {
        'route': 'groups',
        'id': 7,
      });
      expect(decodeNotificationPayload('messages'), {'route': 'messages'});
    });
  });
}
