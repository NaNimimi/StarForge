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

/// Stable event identity shared by FCM and the API notification feed.
///
/// Message ids are globally unique on the messaging backend and are present
/// both in FCM data and in `notification.data`. Prefer them over the outer
/// notification row id so an immediate push and a later feed refresh cannot
/// play two sounds for the same message.
String notificationDedupeKey(Map<String, dynamic> payload) {
  final nested = payload['data'];
  final values = <String, dynamic>{
    if (nested is Map) ...Map<String, dynamic>.from(nested),
    ...payload,
  };
  String value(String key) => values[key]?.toString().trim() ?? '';
  final messageId = value('message_id');
  if (messageId.isNotEmpty) return 'message:$messageId';
  final eventId = value('event_id');
  if (eventId.isNotEmpty) return 'event:$eventId';
  final notificationId = value('notification_id');
  if (notificationId.isNotEmpty) return 'notification:$notificationId';
  final id = value('id');
  if (id.isNotEmpty) return 'notification:$id';
  final createdAt = value('created_at');
  final eventType = value('event_type');
  if (createdAt.isNotEmpty || eventType.isNotEmpty) {
    return 'event:$eventType:$createdAt';
  }
  return '';
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
  static const _channelName = 'Уведомления StarForge EDU';
  static const _channelDescription =
      'Сообщения, платежи, посещаемость и важные события';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, dynamic>> _tapController =
      StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, DateTime> _recentlyShown = <String, DateTime>{};
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
    final now = DateTime.now();
    _recentlyShown.removeWhere(
      (_, shownAt) => now.difference(shownAt) > const Duration(minutes: 10),
    );
    final eventKey = notificationDedupeKey(payload);
    if (eventKey.isNotEmpty && _recentlyShown.containsKey(eventKey)) return;
    if (eventKey.isNotEmpty) _recentlyShown[eventKey] = now;
    final safeTitle = title.trim().isEmpty ? 'StarForge EDU' : title.trim();
    final safeBody = body.trim().isEmpty
        ? 'Откройте приложение, чтобы посмотреть новое событие.'
        : body.trim();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.private,
        ticker: 'StarForge EDU',
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(
          safeBody,
          contentTitle: safeTitle,
          summaryText: 'StarForge EDU',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      id,
      safeTitle,
      safeBody,
      details,
      payload: jsonEncode(payload),
    );
  }
}
