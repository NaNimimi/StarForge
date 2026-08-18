import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

typedef PushDeviceRegistrar =
    Future<Object?> Function(Map<String, Object?> body);

const MethodChannel _firebaseConfigChannel = MethodChannel(
  'com.starforge.ceo_manager/firebase_config',
);

const _firebaseApiKey = String.fromEnvironment('STARFORGE_FIREBASE_API_KEY');
const _firebaseAppId = String.fromEnvironment('STARFORGE_FIREBASE_APP_ID');
const _firebaseAndroidApiKey = String.fromEnvironment(
  'STARFORGE_FIREBASE_ANDROID_API_KEY',
);
const _firebaseAndroidAppId = String.fromEnvironment(
  'STARFORGE_FIREBASE_ANDROID_APP_ID',
);
const _firebaseIosApiKey = String.fromEnvironment(
  'STARFORGE_FIREBASE_IOS_API_KEY',
);
const _firebaseIosAppId = String.fromEnvironment(
  'STARFORGE_FIREBASE_IOS_APP_ID',
);
const _firebaseMessagingSenderId = String.fromEnvironment(
  'STARFORGE_FIREBASE_MESSAGING_SENDER_ID',
);
const _firebaseProjectId = String.fromEnvironment(
  'STARFORGE_FIREBASE_PROJECT_ID',
);
const _firebaseStorageBucket = String.fromEnvironment(
  'STARFORGE_FIREBASE_STORAGE_BUCKET',
);
const _firebaseIosBundleId = String.fromEnvironment(
  'STARFORGE_FIREBASE_IOS_BUNDLE_ID',
  defaultValue: 'com.starforge.ceoManager',
);

String _platformValue(String platformValue, String commonValue) =>
    platformValue.trim().isNotEmpty ? platformValue.trim() : commonValue.trim();

FirebaseOptions? firebaseOptionsFromValues({
  required String apiKey,
  required String appId,
  required String messagingSenderId,
  required String projectId,
  String storageBucket = '',
  String iosBundleId = '',
}) {
  final requiredValues = [apiKey, appId, messagingSenderId, projectId];
  if (requiredValues.any((value) => value.trim().isEmpty)) return null;
  return FirebaseOptions(
    apiKey: apiKey.trim(),
    appId: appId.trim(),
    messagingSenderId: messagingSenderId.trim(),
    projectId: projectId.trim(),
    storageBucket: storageBucket.trim().isEmpty ? null : storageBucket.trim(),
    iosBundleId: iosBundleId.trim().isEmpty ? null : iosBundleId.trim(),
  );
}

FirebaseOptions? _firebaseOptionsFromEnvironment(TargetPlatform platform) {
  final apple = platform == TargetPlatform.iOS;
  return firebaseOptionsFromValues(
    apiKey: _platformValue(
      apple ? _firebaseIosApiKey : _firebaseAndroidApiKey,
      _firebaseApiKey,
    ),
    appId: _platformValue(
      apple ? _firebaseIosAppId : _firebaseAndroidAppId,
      _firebaseAppId,
    ),
    messagingSenderId: _firebaseMessagingSenderId,
    projectId: _firebaseProjectId,
    storageBucket: _firebaseStorageBucket,
    iosBundleId: apple ? _firebaseIosBundleId : '',
  );
}

String pushPlatformName(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  _ => 'unsupported',
};

Map<String, Object?> pushDeviceRegistrationBody({
  required String deviceId,
  required String platform,
  required String token,
}) => <String, Object?>{
  'device_id': deviceId,
  'platform': platform,
  'push_token': token,
  'user_agent': 'StarForge EDU $platform',
};

String notificationRouteFromPayload(Map<String, dynamic> payload) {
  // Message pushes carry private pointers only. Prefer the thread destination
  // even when the generic notification fallback was added by the client.
  if (payload['thread_id']?.toString().trim().isNotEmpty == true) {
    return 'messages';
  }
  const routeKeys = ['route', 'screen', 'target', 'resource'];
  for (final key in routeKeys) {
    final raw = payload[key]?.toString().trim() ?? '';
    if (raw.isEmpty) continue;
    var route = raw
        .replaceFirst(RegExp(r'^https?://[^/]+/?'), '')
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'^api/v1/'), '')
        .split('?')
        .first
        .split('#')
        .first
        .split('/')
        .first
        .trim()
        .toLowerCase();
    const aliases = {
      'notification': 'notifications',
      'notification_detail': 'notifications',
      'user': 'me',
      'profile': 'me',
      'branch': 'branches',
      'student': 'students',
      'group': 'groups',
      'teacher': 'teachers',
      'parent': 'parents',
      'department': 'departments',
      'payment': 'payments',
      'message': 'messages',
      'thread': 'messages',
    };
    route = aliases[route] ?? route;
    if (route.isNotEmpty) return route;
  }
  return 'notifications';
}

Map<String, dynamic> _payloadForMessage(RemoteMessage message) {
  final payload = <String, dynamic>{...message.data};
  final notification = message.notification;
  // Preserve the backend messaging id carried in `data.message_id`: the API
  // notification feed contains the same value and uses it to suppress a
  // delayed duplicate sound. The transport id is useful diagnostics only.
  if (message.messageId case final id?) {
    payload['fcm_message_id'] = id;
    payload.putIfAbsent('message_id', () => id);
  }
  if (notification?.title case final title?) payload['title'] = title;
  if (notification?.body case final body?) payload['body'] = body;
  payload.putIfAbsent('route', () => 'notifications');
  final kind = '${payload['event_type'] ?? payload['type'] ?? payload['route']}'
      .toLowerCase();
  final title = payload['title']?.toString().trim() ?? '';
  if (title.isEmpty) {
    payload['title'] = kind.contains('message') || kind.contains('thread')
        ? 'Новое сообщение'
        : kind.contains('payment') || kind.contains('invoice')
        ? 'Новый платёж'
        : kind.contains('attendance')
        ? 'Посещаемость обновлена'
        : kind.contains('risk') || kind.contains('anomal')
        ? 'Важный сигнал'
        : 'StarForge EDU';
  }
  final body = payload['body']?.toString().trim() ?? '';
  if (body.isEmpty) {
    payload['body'] = payload['message']?.toString().trim().isNotEmpty == true
        ? payload['message'].toString().trim()
        : 'Откройте приложение, чтобы посмотреть подробности.';
  }
  return payload;
}

int _notificationId(RemoteMessage message) {
  final source = message.messageId ?? '${message.sentTime}:${message.data}';
  return source.hashCode & 0x7fffffff;
}

@pragma('vm:entry-point')
Future<void> starforgeFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp(
      options: _firebaseOptionsFromEnvironment(defaultTargetPlatform),
    );
    // Notification payloads are displayed by Android/iOS automatically. A
    // data-only message needs a local notification to be visible to the user.
    if (message.notification == null) {
      final payload = _payloadForMessage(message);
      await DeviceNotificationService.instance.show(
        id: _notificationId(message),
        title: payload['title']?.toString().trim().isNotEmpty == true
            ? payload['title'].toString()
            : 'StarForge EDU',
        body: payload['body']?.toString().trim().isNotEmpty == true
            ? payload['body'].toString()
            : 'Откройте приложение, чтобы посмотреть подробности.',
        payload: payload,
      );
    }
  } catch (_) {
    // A missing native Firebase project must never prevent the app from
    // starting. This handler can only become active once real config exists.
  }
}

/// Native Firebase Cloud Messaging bridge.
///
/// No project identifiers are fabricated here. Android/iOS report whether a
/// real native Firebase configuration is bundled; without one this service is
/// disabled while the existing API notification feed remains usable.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const _deviceIdPreference = 'starforge.push.device_id';

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _tapSubscription;
  StreamSubscription<String>? _tokenSubscription;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  PushDeviceRegistrar? _registrar;
  String? _lastRegisteredToken;
  String? _currentToken;
  Timer? _registrationRetry;
  int _registrationAttempt = 0;
  bool _registrationInFlight = false;
  bool _registered = false;
  bool _initialized = false;
  bool _available = false;
  String? _initializationError;
  String? _registrationError;

  bool get available => _available;
  bool get registered => _registered;
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  String? get initializationError => _initializationError;
  String? get registrationError => _registrationError;

  Future<bool> initialize() async {
    if (_initialized) return _available;
    _initialized = true;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }

    try {
      final options = _firebaseOptionsFromEnvironment(defaultTargetPlatform);
      var hasNativeConfiguration = false;
      if (options == null) {
        try {
          hasNativeConfiguration =
              await _firebaseConfigChannel.invokeMethod<bool>(
                'hasNativeFirebaseConfig',
              ) ??
              false;
        } on MissingPluginException {
          hasNativeConfiguration = false;
        }
      }
      if (options == null && !hasNativeConfiguration) {
        _initializationError = 'native_firebase_config_missing';
        return false;
      }

      await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(
        starforgeFirebaseMessagingBackgroundHandler,
      );
      final messaging = FirebaseMessaging.instance;
      // Foreground messages are rendered through the app's existing high
      // priority local channel, preventing duplicate banners on Apple devices.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _tapSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleMessageTap,
      );
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        _currentToken = token.trim();
        _lastRegisteredToken = null;
        _registered = false;
        unawaited(retryRegistration());
      });
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleMessageTap(initialMessage);
      _available = true;
      _initializationError = null;
      return true;
    } catch (error) {
      _available = false;
      _initializationError = error.runtimeType.toString();
      return false;
    }
  }

  Future<void> bindAuthenticatedSession(PushDeviceRegistrar registrar) async {
    _registrar = registrar;
    _lastRegisteredToken = null;
    _currentToken = null;
    _registered = false;
    _registrationAttempt = 0;
    _registrationRetry?.cancel();
    if (!await initialize()) return;
    try {
      await DeviceNotificationService.instance.requestPermission();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Modern Apple Firebase SDKs require an APNs token before getToken().
        for (var attempt = 0; attempt < 8; attempt++) {
          if (await FirebaseMessaging.instance.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      _currentToken = token?.trim();
      await _registerCurrentToken();
    } catch (error) {
      _registrationError = error.runtimeType.toString();
      _scheduleRegistrationRetry();
    }
  }

  void unbindAuthenticatedSession() {
    _registrationRetry?.cancel();
    _registrationRetry = null;
    _registrar = null;
    _lastRegisteredToken = null;
    _currentToken = null;
    _registered = false;
    _registrationAttempt = 0;
  }

  /// Reconciles a temporarily failed/null token without requiring logout.
  /// Called by the bounded retry timer and whenever the app resumes.
  Future<void> retryRegistration() async {
    if (_registrar == null || !_available || _registered) return;
    _registrationRetry?.cancel();
    _registrationRetry = null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.trim().isNotEmpty) {
        _currentToken = token.trim();
      }
      await _registerCurrentToken();
    } catch (error) {
      _registrationError = error.runtimeType.toString();
      _scheduleRegistrationRetry();
    }
  }

  Future<void> _registerCurrentToken() async {
    if (_registrationInFlight || _registrar == null || _registered) return;
    final token = _currentToken?.trim() ?? '';
    if (token.isEmpty) {
      _registrationError = 'fcm_token_unavailable';
      _scheduleRegistrationRetry();
      return;
    }
    _registrationInFlight = true;
    try {
      if (await _submitToken(token)) {
        _registered = true;
        _registrationAttempt = 0;
        _registrationRetry?.cancel();
        _registrationRetry = null;
      } else {
        _scheduleRegistrationRetry();
      }
    } finally {
      _registrationInFlight = false;
    }
  }

  void _scheduleRegistrationRetry() {
    if (_registrar == null || _registered || _registrationRetry != null) {
      return;
    }
    const delays = <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 2),
    ];
    final delay = delays[_registrationAttempt.clamp(0, delays.length - 1)];
    _registrationAttempt++;
    _registrationRetry = Timer(delay, () {
      _registrationRetry = null;
      unawaited(retryRegistration());
    });
  }

  Future<bool> _submitToken(String token) async {
    final registrar = _registrar;
    final normalizedToken = token.trim();
    if (registrar == null || normalizedToken.isEmpty) {
      return false;
    }
    if (normalizedToken == _lastRegisteredToken) {
      return true;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString(_deviceIdPreference)?.trim() ?? '';
      if (deviceId.isEmpty) {
        final random = Random.secure();
        final bytes = List<int>.generate(20, (_) => random.nextInt(256));
        deviceId =
            'sf_${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
        await prefs.setString(_deviceIdPreference, deviceId);
      }
      await registrar(
        pushDeviceRegistrationBody(
          deviceId: deviceId,
          platform: pushPlatformName(defaultTargetPlatform),
          token: normalizedToken,
        ),
      );
      _lastRegisteredToken = normalizedToken;
      _registrationError = null;
      return true;
    } catch (error) {
      // Some published backend schemas expose the endpoint but not yet the
      // push_token field. Keep login and the workspace operational while
      // retaining a diagnostic that can be surfaced by support tooling.
      _registrationError = error.runtimeType.toString();
      return false;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final payload = _payloadForMessage(message);
    await DeviceNotificationService.instance.show(
      id: _notificationId(message),
      title: payload['title']?.toString().trim().isNotEmpty == true
          ? payload['title'].toString()
          : 'StarForge EDU',
      body: payload['body']?.toString().trim().isNotEmpty == true
          ? payload['body'].toString()
          : 'Откройте приложение, чтобы посмотреть подробности.',
      payload: payload,
    );
    _messageController.add(payload);
  }

  void _handleMessageTap(RemoteMessage message) {
    DeviceNotificationService.instance.ingestRemoteTap(
      _payloadForMessage(message),
    );
  }

  Future<void> dispose() async {
    _registrationRetry?.cancel();
    await _foregroundSubscription?.cancel();
    await _tapSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messageController.close();
  }
}

bool shouldPresentNotificationPollingFallback({
  required bool pushAvailable,
  required bool pushRegistered,
}) => !pushAvailable || !pushRegistered;
