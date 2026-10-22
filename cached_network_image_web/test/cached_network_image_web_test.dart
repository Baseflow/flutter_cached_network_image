// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image_platform_interface'
    '/cached_network_image_platform_interface.dart'
    hide ImageLoader;
import 'package:cached_network_image_web/cached_network_image_web.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loadImageAsync returns a stream', () {
    final imageLoader = ImageLoader();
    final stream = imageLoader.loadImageAsync(
      'test.com/image',
      null,
      StreamController<ImageChunkEvent>(),
      decoder,
      MockCacheManager(),
      null,
      null,
      null,
      ImageRenderMethodForWeb.HttpGet,
      () => {},
    );
    expect(stream, isNotNull);
  });

  group('HttpGet with a cached file', () {
    const url = 'https://example.com/image.webp';
    late _StreamingCacheManager cacheManager;
    late List<Object> uncaught;
    late List<Object> streamErrors;
    late List<ui.Codec> codecs;
    late int evicted;
    late bool done;
    late bool chunkEventsDone;

    FileInfo fileInfo() {
      final file = MemoryFileSystem().file('/image.webp')
        ..writeAsBytesSync([0, 1, 2, 3]);
      return FileInfo(
        file,
        FileSource.Online,
        DateTime.now().add(const Duration(days: 1)),
        url,
      );
    }

    Future<void> load(
      ImageDecoderCallback decode, {
      String? cacheKey,
      bool failRemove = false,
    }) async {
      uncaught = [];
      streamErrors = [];
      codecs = [];
      evicted = 0;
      done = false;
      chunkEventsDone = false;
      cacheManager = _StreamingCacheManager(failRemove: failRemove);
      await runZonedGuarded(() async {
        final chunkEvents = StreamController<ImageChunkEvent>();
        chunkEvents.stream.listen((_) {}, onDone: () => chunkEventsDone = true);
        ImageLoader()
            .loadImageAsync(
              url,
              cacheKey,
              chunkEvents,
              decode,
              cacheManager,
              null,
              null,
              null,
              ImageRenderMethodForWeb.HttpGet,
              () => evicted++,
            )
            .listen(
              codecs.add,
              onError: streamErrors.add,
              onDone: () => done = true,
            );
        cacheManager.events.add(fileInfo());
        await cacheManager.events.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }, (e, _) => uncaught.add(e));
    }

    test('reports a decode failure to the stream and cleans up', () async {
      await load((buffer, {getTargetSize}) async {
        buffer.dispose();
        throw StateError('invalid image bytes');
      }, cacheKey: 'custom-key');

      expect(uncaught, isEmpty);
      expect(streamErrors, hasLength(1));
      expect(streamErrors.single, isA<StateError>());
      expect(evicted, 1);
      expect(done, isTrue);
      expect(chunkEventsDone, isTrue);
      expect(cacheManager.removedKeys, ['custom-key']);
    });

    test('removes the broken file under the url when no key is set', () async {
      await load((buffer, {getTargetSize}) async {
        buffer.dispose();
        throw StateError('invalid image bytes');
      });

      expect(cacheManager.removedKeys, [url]);
    });

    test(
      'still reports the decode failure if removing the file fails',
      () async {
        await load((buffer, {getTargetSize}) async {
          buffer.dispose();
          throw StateError('invalid image bytes');
        }, failRemove: true);

        expect(uncaught, isEmpty);
        expect(streamErrors.single, isA<StateError>());
        expect(done, isTrue);
      },
    );

    test('closes the streams once the file is decoded', () async {
      await load((buffer, {getTargetSize}) async {
        buffer.dispose();
        return _FakeCodec();
      });

      expect(uncaught, isEmpty);
      expect(streamErrors, isEmpty);
      expect(codecs, hasLength(1));
      expect(evicted, 0);
      expect(done, isTrue);
      expect(chunkEventsDone, isTrue);
      expect(cacheManager.removedKeys, isEmpty);
    });
  });
}

class _FakeCodec implements ui.Codec {
  @override
  void dispose() {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StreamingCacheManager extends MockCacheManager {
  _StreamingCacheManager({this.failRemove = false});

  final bool failRemove;
  final events = StreamController<FileResponse>();
  final removedKeys = <String>[];

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => events.stream;

  @override
  Future<void> removeFile(String key) async {
    removedKeys.add(key);
    if (failRemove) throw StateError('remove failed');
  }
}

Future<ui.Codec> decoder(
  ui.ImmutableBuffer buffer, {
  ui.TargetImageSizeCallback? getTargetSize,
}) {
  throw UnimplementedError();
}

class MockCacheManager implements BaseCacheManager {
  @override
  Future<void> dispose() {
    throw UnimplementedError();
  }

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> emptyCache() {
    throw UnimplementedError();
  }

  @override
  Stream<FileInfo> getFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FileInfo?> getFileFromMemory(String key) {
    throw UnimplementedError();
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<File> putFileStream(
    String url,
    Stream<List<int>> source, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeFile(String key) {
    throw UnimplementedError();
  }
}
