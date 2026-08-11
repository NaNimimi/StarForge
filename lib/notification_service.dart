import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Map<String, dynamic> decodeNotificationPayload(Object? payload) {
  if (payload is Map) return Map<String, dynamic>.from(payload);
  final text = payload?.toString().trim() ?? '';
  if (text.isEmpty) return const {};
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    // Older/local senders may use a route string instead of JSON.
  }
  return {'route': text};
}

/// Device-notification bridge for events already issued by the StarForge API.
///
/// This is deliberately separate from the API session: the backend remains the
/// authority for who receives an alert and when it is read, while this service
/// is responsible for the native permission prompt and foreground display.
class DeviceNotificationService {
  DeviceNotificationService._();

  static final DeviceNotificationService instance =
      DeviceNotificationService._();

  // Must match infrastructure/push/fcm_client.py on the StarForge backend.
  static const _channelId = 'starforge_messages';
  static const _channelName = 'StarForge messages';
  static const _channelDescription =
      'Approvals, attendance, payment and risk alerts';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, dynamic>> _tapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? _pendingTapPayload;
  bool _initialized = false;

  Stream<Map<String, dynamic>> get notificationTaps => _tapController.stream;

  /// Returns a notification that launched the process before the UI subscribed.
  Map<String, dynamic>? takePendingTapPayload() {
    final payload = _pendingTapPayload;
    _pendingTapPayload = null;
    return payload;
  }

  void ingestRemoteTap(Map<String, dynamic> payload) => _recordTap(payload);

  void _recordTap(Map<String, dynamic> payload) {
    final normalized = payload.isEmpty
        ? <String, dynamic>{'route': 'notifications'}
        : Map<String, dynamic>.from(payload);
    _pendingTapPayload = normalized;
    _tapController.add(normalized);
  }

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
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _recordTap(decodeNotificationPayload(response.payload));
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _recordTap(
        decodeNotificationPayload(launchDetails?.notificationResponse?.payload),
      );
    }
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
    Map<String, dynamic> payload = const {},
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
    await _plugin.show(id, title, body, details, payload: jsonEncode(payload));
  }
}
