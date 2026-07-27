import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Device-notification bridge for events already issued by the StarForge API.
///
/// This is deliberately separate from the API session: the backend remains the
/// authority for who receives an alert and when it is read, while this service
/// is responsible for the native permission prompt and foreground display.
class DeviceNotificationService {
  DeviceNotificationService._();

  static final DeviceNotificationService instance =
      DeviceNotificationService._();

  static const _channelId = 'starforge_alerts';
  static const _channelName = 'StarForge alerts';
  static const _channelDescription =
      'Approvals, attendance, payment and risk alerts';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// The prompt is deferred until the user has connected an account. This
  /// avoids requesting a sensitive OS permission from the preview workspace.
  Future<void> requestPermission() async {
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(id, title, body, details);
  }
}
