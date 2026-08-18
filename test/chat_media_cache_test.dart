import 'dart:io';
import 'dart:typed_data';

import 'package:ceo_manager/chat_media_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    root = await Directory.systemTemp.createTemp('starforge-chat-media-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'first media read downloads once and subsequent reads are local',
    () async {
      var downloads = 0;
      final cache = ChatMediaCache(
        rootProvider: () async => root,
        downloader: (_) async {
          downloads += 1;
          return Uint8List.fromList(<int>[1, 2, 3, 4]);
        },
      );
      await cache.configure('https://api.test|tenant-a|user-10');

      Future<String> resolve() async => 'https://objects.test/voice';
      final first = await cache.obtain(
        key: 'messages/1/voice.m4a',
        mimeType: 'audio/mp4',
        resolveDownloadUrl: resolve,
      );
      final second = await cache.obtain(
        key: 'messages/1/voice.m4a',
        mimeType: 'audio/mp4',
        resolveDownloadUrl: resolve,
      );

      expect(downloads, 1);
      expect(second, first);
      expect(await File(first).readAsBytes(), <int>[1, 2, 3, 4]);
    },
  );

  test(
    'media namespaces and logout cleanup are isolated per account',
    () async {
      var downloads = 0;
      final cache = ChatMediaCache(
        rootProvider: () async => root,
        downloader: (_) async => Uint8List.fromList(<int>[++downloads]),
      );
      Future<String> resolve() async => 'https://objects.test/file';

      await cache.configure('api|tenant|user-a');
      final accountA = await cache.obtain(
        key: 'same-key.m4a',
        mimeType: 'audio/mp4',
        resolveDownloadUrl: resolve,
      );
      await cache.flush();

      await cache.configure('api|tenant|user-b');
      expect(await cache.localPath('same-key.m4a'), isNull);
      final accountB = await cache.obtain(
        key: 'same-key.m4a',
        mimeType: 'audio/mp4',
        resolveDownloadUrl: resolve,
      );
      expect(accountB, isNot(accountA));
      expect(downloads, 2);

      await cache.clearCurrentUser();
      expect(await File(accountB).exists(), isFalse);
      expect(await File(accountA).exists(), isTrue);

      await cache.configure('api|tenant|user-a');
      expect(await cache.localPath('same-key.m4a'), accountA);
    },
  );

  test('LRU never removes a file protected by active playback', () async {
    var value = 0;
    final cache = ChatMediaCache(
      maximumBytes: 5,
      rootProvider: () async => root,
      downloader: (_) async => Uint8List.fromList(List<int>.filled(4, ++value)),
    );
    await cache.configure('api|tenant|user-a');
    Future<String> resolve() async => 'https://objects.test/file';
    final playing = await cache.obtain(
      key: 'voice-a.m4a',
      mimeType: 'audio/mp4',
      resolveDownloadUrl: resolve,
    );
    cache.protect(playing);
    final newest = await cache.obtain(
      key: 'voice-b.m4a',
      mimeType: 'audio/mp4',
      resolveDownloadUrl: resolve,
    );

    expect(await File(playing).exists(), isTrue);
    expect(await File(newest).exists(), isTrue);
    cache.unprotect(playing);
    await cache.flush();
    expect(await File(playing).exists(), isFalse);
    expect(await File(newest).exists(), isTrue);
  });
}
