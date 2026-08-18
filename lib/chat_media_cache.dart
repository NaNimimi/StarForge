import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ChatBytesDownloader = Future<Uint8List> Function(Uri uri);
typedef ChatCacheRootProvider = Future<Directory> Function();

class ChatCachedAttachment {
  const ChatCachedAttachment({
    required this.key,
    required this.localPath,
    required this.mimeType,
    required this.sizeBytes,
    required this.lastAccessedAt,
  });

  final String key;
  final String localPath;
  final String mimeType;
  final int sizeBytes;
  final DateTime lastAccessedAt;

  ChatCachedAttachment touch() => ChatCachedAttachment(
    key: key,
    localPath: localPath,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    lastAccessedAt: DateTime.now().toUtc(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'local_path': localPath,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'last_accessed_at': lastAccessedAt.toIso8601String(),
  };

  static ChatCachedAttachment? fromJson(Object? value) {
    if (value is! Map) return null;
    final row = Map<String, dynamic>.from(value);
    final key = '${row['key'] ?? ''}'.trim();
    final path = '${row['local_path'] ?? ''}'.trim();
    final accessed = DateTime.tryParse('${row['last_accessed_at'] ?? ''}');
    if (key.isEmpty || path.isEmpty || accessed == null) return null;
    return ChatCachedAttachment(
      key: key,
      localPath: path,
      mimeType: '${row['mime_type'] ?? 'application/octet-stream'}',
      sizeBytes: int.tryParse('${row['size_bytes'] ?? 0}') ?? 0,
      lastAccessedAt: accessed,
    );
  }
}

/// Account-scoped, bounded media cache for chat attachments.
///
/// The cache stores only public/presigned attachment bytes and metadata. It
/// never receives or persists the API bearer token. Every directory and index
/// is isolated by the already-normalized API/tenant/user identity.
class ChatMediaCache {
  ChatMediaCache({
    this.maximumBytes = 150 * 1024 * 1024,
    ChatCacheRootProvider? rootProvider,
    ChatBytesDownloader? downloader,
  }) : _rootProvider = rootProvider ?? getApplicationCacheDirectory,
       _downloader = downloader ?? _download;

  final int maximumBytes;
  final ChatCacheRootProvider _rootProvider;
  final ChatBytesDownloader _downloader;
  final Map<String, ChatCachedAttachment> _entries = {};
  final Set<String> _protectedPaths = {};
  final Map<String, Future<String>> _inFlight = {};
  String? _identityHash;
  Directory? _directory;
  Future<void> _writeQueue = Future<void>.value();
  bool _clearRequested = false;

  static Future<Uint8List> _download(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Attachment download failed (${response.statusCode})',
        uri: uri,
      );
    }
    return response.bodyBytes;
  }

  String get _indexKey => 'starforge.chat.media.${_identityHash ?? 'none'}.v1';

  Future<void> configure(String identity) async {
    final normalized = identity.trim();
    if (normalized.isEmpty) return;
    final hash = sha256.convert(utf8.encode(normalized)).toString();
    if (_identityHash == hash) return;
    await _writeQueue;
    _entries.clear();
    _protectedPaths.clear();
    _inFlight.clear();
    _identityHash = hash;
    final root = await _rootProvider();
    _directory = Directory('${root.path}/starforge_chat/$hash');
    if (!await _directory!.exists()) {
      await _directory!.create(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_indexKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final rows = jsonDecode(encoded);
        if (rows is List) {
          for (final raw in rows) {
            final entry = ChatCachedAttachment.fromJson(raw);
            if (entry == null) continue;
            final file = File(entry.localPath);
            if (await file.exists()) _entries[entry.key] = entry;
          }
        }
      } catch (_) {
        // A corrupt index is discarded; attachment files are disposable.
      }
    }
    await _evictIfNeeded();
  }

  Future<String?> localPath(String key) async {
    final value = key.trim();
    final entry = _entries[value];
    if (entry == null) return null;
    final file = File(entry.localPath);
    if (!await file.exists()) {
      _entries.remove(value);
      _schedulePersist();
      return null;
    }
    _entries[value] = entry.touch();
    _schedulePersist();
    return entry.localPath;
  }

  Future<String> obtain({
    required String key,
    required String mimeType,
    required Future<String> Function() resolveDownloadUrl,
  }) async {
    final value = key.trim();
    if (value.isEmpty || _directory == null) {
      throw StateError('Chat media cache is not configured');
    }
    final cached = await localPath(value);
    if (cached != null) return cached;
    final pending = _inFlight[value];
    if (pending != null) return pending;
    final future = () async {
      final url = Uri.parse(await resolveDownloadUrl());
      final bytes = await _downloader(url);
      final extension = _extension(value, mimeType);
      final filename = '${sha256.convert(utf8.encode(value))}$extension';
      final target = File('${_directory!.path}/$filename');
      await target.writeAsBytes(bytes, flush: true);
      _entries[value] = ChatCachedAttachment(
        key: value,
        localPath: target.path,
        mimeType: mimeType,
        sizeBytes: bytes.length,
        lastAccessedAt: DateTime.now().toUtc(),
      );
      await _evictIfNeeded(keepPath: target.path);
      _schedulePersist();
      return target.path;
    }();
    _inFlight[value] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(value);
    }
  }

  void protect(String path) => _protectedPaths.add(path);
  void unprotect(String path) {
    _protectedPaths.remove(path);
    if (_clearRequested && _protectedPaths.isEmpty) {
      unawaited(clearCurrentUser());
    } else {
      _writeQueue = _writeQueue
          .then((_) async {
            await _evictIfNeeded();
            await _persist();
          })
          .catchError((_) {});
    }
  }

  Future<void> _evictIfNeeded({String? keepPath}) async {
    var total = _entries.values.fold<int>(
      0,
      (sum, item) => sum + item.sizeBytes,
    );
    if (total <= maximumBytes) return;
    final candidates = _entries.values.toList()
      ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
    for (final entry in candidates) {
      if (total <= maximumBytes) break;
      if (entry.localPath == keepPath ||
          _protectedPaths.contains(entry.localPath)) {
        continue;
      }
      final file = File(entry.localPath);
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        continue;
      }
      _entries.remove(entry.key);
      total -= entry.sizeBytes;
    }
  }

  Future<void> clearCurrentUser() async {
    _clearRequested = true;
    await _writeQueue;
    for (final entry in _entries.values.toList()) {
      if (_protectedPaths.contains(entry.localPath)) continue;
      try {
        final file = File(entry.localPath);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Best effort logout cleanup.
      }
    }
    _entries.removeWhere(
      (_, entry) => !_protectedPaths.contains(entry.localPath),
    );
    final prefs = await SharedPreferences.getInstance();
    if (_entries.isEmpty) {
      await prefs.remove(_indexKey);
      _clearRequested = false;
    } else {
      await _persist();
    }
  }

  void _schedulePersist() {
    _writeQueue = _writeQueue.then((_) => _persist()).catchError((_) {});
  }

  Future<void> _persist() async {
    if (_identityHash == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _indexKey,
      jsonEncode(_entries.values.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> flush() => _writeQueue;

  static String _extension(String key, String mimeType) {
    final clean = key.split('?').first.toLowerCase();
    final dot = clean.lastIndexOf('.');
    if (dot >= 0 && clean.length - dot <= 6) return clean.substring(dot);
    return switch (mimeType.toLowerCase()) {
      'audio/mp4' => '.m4a',
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      'video/mp4' => '.mp4',
      _ => '.bin',
    };
  }
}
