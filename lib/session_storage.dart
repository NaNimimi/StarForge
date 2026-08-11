import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal encrypted session snapshot. Passwords are deliberately never
/// persisted; the opaque bearer key is enough to restore a server session.
class PersistedApiSession {
  const PersistedApiSession({
    required this.baseUrl,
    required this.token,
    required this.profile,
  });

  final String baseUrl;
  final String token;
  final Map<String, dynamic> profile;

  Map<String, dynamic> toJson() => {
    'base_url': baseUrl,
    'token': token,
    'profile': profile,
  };

  static PersistedApiSession? fromJson(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final baseUrl = '${map['base_url'] ?? ''}'.trim();
    final token = '${map['token'] ?? ''}'.trim();
    final rawProfile = map['profile'];
    if (baseUrl.isEmpty || token.isEmpty || rawProfile is! Map) return null;
    return PersistedApiSession(
      baseUrl: baseUrl,
      token: token,
      profile: Map<String, dynamic>.from(rawProfile),
    );
  }
}

abstract interface class ApiSessionStorage {
  Future<PersistedApiSession?> read();
  Future<void> write(PersistedApiSession session);
  Future<void> clear();
}

/// Android uses encrypted SharedPreferences backed by the system keystore;
/// iOS uses Keychain. The single JSON value makes a token/profile update
/// atomic from the app's point of view.
class SecureApiSessionStorage implements ApiSessionStorage {
  SecureApiSessionStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const _key = 'starforge.api.session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<PersistedApiSession?> read() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final session = PersistedApiSession.fromJson(jsonDecode(encoded));
      if (session == null) await clear();
      return session;
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(PersistedApiSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Test/preview implementation that never invokes a platform plugin.
class MemoryApiSessionStorage implements ApiSessionStorage {
  MemoryApiSessionStorage([this.value]);

  PersistedApiSession? value;

  @override
  Future<PersistedApiSession?> read() async => value;

  @override
  Future<void> write(PersistedApiSession session) async => value = session;

  @override
  Future<void> clear() async => value = null;
}
