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

  group('HttpGet with cached files', () {
    const url = 'https://example.com/image.webp';
    // The decoder tells files apart by their length: `stale` is the cached
    // copy, `fresh` the one that is downloaded afterwards.
    const stale = 3;
    const fresh = 4;

    late _StreamingCacheManager cacheManager;
    late List<Object> uncaught;
    late List<Object> streamErrors;
    late List<ui.Codec> codecs;
    late Map<int, Completer<ui.Codec>> decodes;
    late Completer<void> streamDone;
    late Completer<void> chunkEventsDone;
    late int evicted;

    // Lets every pending microtask run, e.g. a decode that was just completed.
    Future<void> flush() => Future<void>.delayed(Duration.zero);

    Completer<ui.Codec> decodeOf(int length) =>
        decodes.putIfAbsent(length, Completer<ui.Codec>.new);

    void decodeSucceeds(int length) => decodeOf(length).complete(_FakeCodec());

    void decodeFails(int length) =>
        decodeOf(length).completeError(StateError('invalid image $length'));

    FileInfo fileInfo(int length) {
      final file = MemoryFileSystem().file('/image-$length.webp')
        ..writeAsBytesSync(List<int>.filled(length, 1));
      return FileInfo(
        file,
        FileSource.Online,
        DateTime.now().add(const Duration(days: 1)),
        url,
      );
    }

    /// Emits a file and lets its decode start.
    Future<void> emit(int length) async {
      cacheManager.events.add(fileInfo(length));
      await flush();
    }

    /// Ends the download and waits until both streams are closed.
    Future<void> finish() async {
      await cacheManager.events.close();
      await Future.wait([
        streamDone.future,
        chunkEventsDone.future,
      ]).timeout(const Duration(seconds: 5));
    }

    void load({
      String? cacheKey,
      bool failRemove = false,
      Completer<void>? removeGate,
      bool throwOnGet = false,
    }) {
      uncaught = [];
      streamErrors = [];
      codecs = [];
      decodes = {};
      streamDone = Completer<void>();
      chunkEventsDone = Completer<void>();
      evicted = 0;
      cacheManager = _StreamingCacheManager(
        failRemove: failRemove,
        removeGate: removeGate,
        throwOnGet: throwOnGet,
      );
      runZonedGuarded(() {
        final chunkEvents = StreamController<ImageChunkEvent>();
        chunkEvents.stream.listen((_) {}, onDone: chunkEventsDone.complete);
        ImageLoader()
            .loadImageAsync(
              url,
              cacheKey,
              chunkEvents,
              (buffer, {getTargetSize}) {
                final length = buffer.length;
                buffer.dispose();
                return decodeOf(length).future;
              },
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
              onDone: streamDone.complete,
            );
      }, (e, _) => uncaught.add(e));
    }

    test('reports a decode failure to the stream and cleans up', () async {
      load(cacheKey: 'custom-key');
      await emit(stale);
      decodeFails(stale);
      await finish();

      expect(uncaught, isEmpty);
      expect(streamErrors, hasLength(1));
      expect(streamErrors.single, isA<StateError>());
      expect(codecs, isEmpty);
      expect(evicted, 1);
      expect(cacheManager.removedKeys, ['custom-key']);
    });

    test('removes the broken file under the url when no key is set', () async {
      load();
      await emit(stale);
      decodeFails(stale);
      await finish();

      expect(cacheManager.removedKeys, [url]);
    });

    test(
      'still reports the decode failure if removing the file fails',
      () async {
        load(failRemove: true);
        await emit(stale);
        decodeFails(stale);
        await finish();

        expect(uncaught, isEmpty);
        expect(streamErrors.single, isA<StateError>());
        expect(evicted, 1);
      },
    );

    test('evicts the image only after the broken file is removed', () async {
      final removeGate = Completer<void>();
      load(removeGate: removeGate);
      await emit(stale);
      decodeFails(stale);
      await cacheManager.events.close();
      await flush();

      expect(cacheManager.removedKeys, [url]);
      expect(evicted, 0);
      expect(streamErrors, isEmpty);

      removeGate.complete();
      await finish();

      expect(evicted, 1);
      expect(streamErrors, hasLength(1));
    });

    test('closes the streams once the file is decoded', () async {
      load();
      await emit(stale);
      decodeSucceeds(stale);
      await finish();

      expect(uncaught, isEmpty);
      expect(streamErrors, isEmpty);
      expect(codecs, hasLength(1));
      expect(evicted, 0);
      expect(cacheManager.removedKeys, isEmpty);
    });

    test('reports an error thrown while the download starts', () async {
      load(throwOnGet: true);
      await Future.wait([
        streamDone.future,
        chunkEventsDone.future,
      ]).timeout(const Duration(seconds: 5));

      expect(uncaught, isEmpty);
      expect(streamErrors.single, isA<StateError>());
      expect(evicted, 1);
    });

    test('shows the fresh file when the stale one fails to decode', () async {
      load();
      await emit(stale);
      decodeFails(stale);
      await flush();

      // The download is still running, so nothing may be removed yet.
      expect(cacheManager.removedKeys, isEmpty);
      expect(streamErrors, isEmpty);
      expect(evicted, 0);

      await emit(fresh);
      decodeSucceeds(fresh);
      await finish();

      expect(uncaught, isEmpty);
      expect(streamErrors, isEmpty);
      expect(codecs, hasLength(1));
      expect(evicted, 0);
      expect(cacheManager.removedKeys, isEmpty);
    });

    test(
      'reports the failure when the stale and fresh files both fail',
      () async {
        load();
        await emit(stale);
        decodeFails(stale);
        await emit(fresh);
        decodeFails(fresh);
        await flush();

        expect(cacheManager.removedKeys, isEmpty);

        await finish();

        expect(uncaught, isEmpty);
        expect(codecs, isEmpty);
        expect(streamErrors, hasLength(1));
        expect((streamErrors.single as StateError).message, contains('$fresh'));
        expect(evicted, 1);
        expect(cacheManager.removedKeys, [url]);
      },
    );

    test('keeps the image when a later file fails to decode', () async {
      load();
      await emit(stale);
      decodeSucceeds(stale);
      await emit(fresh);
      decodeFails(fresh);
      await finish();

      expect(uncaught, isEmpty);
      expect(codecs, hasLength(1));
      expect(streamErrors, isEmpty);
      expect(evicted, 0);
      expect(cacheManager.removedKeys, isEmpty);
    });

    test(
      'keeps the image when the stale file fails after the fresh one decoded',
      () async {
        load();
        await emit(stale);
        await emit(fresh);
        decodeSucceeds(fresh);
        await flush();
        decodeFails(stale);
        await finish();

        expect(uncaught, isEmpty);
        expect(codecs, hasLength(1));
        expect(streamErrors, isEmpty);
        expect(evicted, 0);
        expect(cacheManager.removedKeys, isEmpty);
      },
    );

    test(
      'closes the streams after a download error following a frame',
      () async {
        load();
        await emit(stale);
        decodeSucceeds(stale);
        await flush();
        cacheManager.events.addError(StateError('download failed'));
        await Future.wait([
          streamDone.future,
          chunkEventsDone.future,
        ]).timeout(const Duration(seconds: 5));

        expect(uncaught, isEmpty);
        expect(codecs, hasLength(1));
        expect(streamErrors.single, isA<StateError>());
        expect(evicted, 1);
        expect(cacheManager.removedKeys, isEmpty);
      },
    );

    test(
      'waits for a pending decode before reporting a download error',
      () async {
        load();
        await emit(stale);
        cacheManager.events.addError(StateError('download failed'));
        await flush();

        expect(streamDone.isCompleted, isFalse);
        expect(streamErrors, isEmpty);

        decodeSucceeds(stale);
        await Future.wait([
          streamDone.future,
          chunkEventsDone.future,
        ]).timeout(const Duration(seconds: 5));

        expect(uncaught, isEmpty);
        expect(codecs, hasLength(1));
        expect(streamErrors, hasLength(1));
        expect(cacheManager.removedKeys, isEmpty);
      },
    );

    test('removes the broken file when the download fails too', () async {
      load();
      await emit(stale);
      decodeFails(stale);
      cacheManager.events.addError(StateError('download failed'));
      await Future.wait([
        streamDone.future,
        chunkEventsDone.future,
      ]).timeout(const Duration(seconds: 5));

      expect(uncaught, isEmpty);
      expect(codecs, isEmpty);
      expect(streamErrors, hasLength(1));
      expect((streamErrors.single as StateError).message, 'download failed');
      expect(cacheManager.removedKeys, [url]);
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
  _StreamingCacheManager({
    this.failRemove = false,
    this.removeGate,
    this.throwOnGet = false,
  });

  final bool failRemove;
  final Completer<void>? removeGate;
  final bool throwOnGet;
  final events = StreamController<FileResponse>();
  final removedKeys = <String>[];

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    if (throwOnGet) throw StateError('cannot start the download');
    return events.stream;
  }

  @override
  Future<void> removeFile(String key) async {
    removedKeys.add(key);
    await removeGate?.future;
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
