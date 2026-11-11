// Copyright 2020 Rene Floor. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Codec, FrameInfo;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_cache_manager.dart';
import 'image_data.dart';
import 'rendering_tester.dart';

void main() {
  TestRenderingFlutterBinding();

  late FakeCacheManager cacheManager;

  setUp(() {
    cacheManager = FakeCacheManager();
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  test('minFrameDuration participates in provider equality and hashCode', () {
    final provider = CachedNetworkImageProvider(
      'animation',
      minFrameDuration: const Duration(milliseconds: 20),
    );
    final sameProvider = CachedNetworkImageProvider(
      'animation',
      minFrameDuration: const Duration(milliseconds: 20),
    );
    final differentProvider = CachedNetworkImageProvider(
      'animation',
      minFrameDuration: const Duration(milliseconds: 30),
    );
    final defaultProvider = CachedNetworkImageProvider('animation');

    expect(provider, sameProvider);
    expect(provider.hashCode, sameProvider.hashCode);
    expect(provider, isNot(differentProvider));
    expect(provider, isNot(defaultProvider));
  });

  test('toString distinguishes non-null frame durations', () {
    expect(
      CachedNetworkImageProvider('animation').toString(),
      'CachedNetworkImageProvider("animation", scale: 1.0)',
    );
    for (final milliseconds in [0, 20, 100]) {
      final minimum = Duration(milliseconds: milliseconds);
      expect(
        CachedNetworkImageProvider(
          'animation',
          minFrameDuration: minimum,
        ).toString(),
        'CachedNetworkImageProvider("animation", scale: 1.0, '
        'minFrameDuration: $minimum)',
      );
    }
  });

  for (final minimum in [null, const Duration(milliseconds: 100)]) {
    for (final cacheKey in [null, 'custom-key']) {
      test('evicts matching timing $minimum and key $cacheKey', () async {
        const url = 'animation';
        final scale = cacheKey == null ? 1.0 : 2.0;
        final provider = CachedNetworkImageProvider(
          url,
          cacheKey: cacheKey,
          scale: scale,
          minFrameDuration: minimum,
        );
        final other = CachedNetworkImageProvider(
          url,
          cacheKey: cacheKey,
          scale: scale,
          minFrameDuration: const Duration(milliseconds: 20),
        );
        for (final key in [provider, other]) {
          final image = await createTestImage(width: 1, height: 1);
          imageCache.putIfAbsent(
            key,
            () => OneFrameImageStreamCompleter(
              Future.value(ImageInfo(image: image)),
            ),
          );
          await Future<void>.delayed(Duration.zero);
          expect(imageCache.statusForKey(key).keepAlive, isTrue);
        }
        when(
          () => cacheManager.removeFile(cacheKey ?? url),
        ).thenAnswer((_) async {});

        expect(
          await CachedNetworkImage.evictFromCache(
            url,
            cacheKey: cacheKey,
            cacheManager: cacheManager,
            scale: scale,
            minFrameDuration: const Duration(milliseconds: 150),
          ),
          isFalse,
        );
        expect(imageCache.statusForKey(provider).keepAlive, isTrue);
        expect(
          await CachedNetworkImage.evictFromCache(
            url,
            cacheKey: cacheKey,
            cacheManager: cacheManager,
            scale: scale,
            minFrameDuration: minimum,
          ),
          isTrue,
        );
        expect(imageCache.statusForKey(provider).untracked, isTrue);
        expect(imageCache.statusForKey(other).keepAlive, isTrue);
        verify(() => cacheManager.removeFile(cacheKey ?? url)).called(2);
      });
    }

    for (final useBuffer in [false, true]) {
      test('passes $minimum to completer (loadBuffer: $useBuffer)', () async {
        const url = 'animation';
        // No bytes are needed: inspect the completer built by each entry point.
        when(
          () => cacheManager.getFileStream(
            url,
            key: any(named: 'key'),
            headers: any(named: 'headers'),
            withProgress: any(named: 'withProgress'),
          ),
        ).thenAnswer((_) => const Stream<FileResponse>.empty());
        final provider = CachedNetworkImageProvider(
          url,
          cacheManager: cacheManager,
          minFrameDuration: minimum,
        );
        final ImageStreamCompleter completer;
        if (useBuffer) {
          // ignore: deprecated_member_use_from_same_package
          completer = provider.loadBuffer(
            provider,
            (buffer, {cacheWidth, cacheHeight, allowUpscaling = false}) =>
                throw StateError('Unexpected decode'),
          );
        } else {
          completer = provider.loadImage(
            provider,
            (buffer, {getTargetSize}) => throw StateError('Unexpected decode'),
          );
        }
        final listener = ImageStreamListener((info, _) => info.dispose());
        completer.addListener(listener);
        addTearDown(() => completer.removeListener(listener));
        expect(
          completer,
          isA<MultiImageStreamCompleter>().having(
            (value) => value.minFrameDuration,
            'minFrameDuration',
            minimum,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }, skip: isBrowser); // The web loader does not use the fake file stream.
    }
  }

  test(
    'Expect thrown exception with statusCode - evicts from cache',
    () async {
      const requestUrl = 'foo-url';
      cacheManager.throwsNotFound(requestUrl);

      final caughtError = Completer<dynamic>();

      final ImageProvider imageProvider = CachedNetworkImageProvider(
        nonconst(requestUrl),
        cacheManager: cacheManager,
      );
      expect(imageCache.pendingImageCount, 0);
      expect(imageCache.statusForKey(imageProvider).untracked, true);

      final result = imageProvider.resolve(ImageConfiguration.empty);

      expect(imageCache.pendingImageCount, 1);
      expect(imageCache.statusForKey(imageProvider).pending, true);

      result.addListener(
        ImageStreamListener(
          (ImageInfo info, bool syncCall) {},
          onError: (Object error, StackTrace? stackTrace) {
            caughtError.complete(error);
          },
        ),
      );

      final dynamic err = await caughtError.future;

      expect(imageCache.pendingImageCount, 0);
      expect(imageCache.statusForKey(imageProvider).untracked, true);

      expect(
        err,
        isA<HttpExceptionWithStatus>()
            .having(
              (HttpExceptionWithStatus e) => e.statusCode,
              'statusCode',
              404,
            )
            .having(
              (HttpExceptionWithStatus e) => e.uri,
              'uri',
              Uri.parse(requestUrl),
            ),
      );
    },
    skip: isBrowser,
  ); // Browser implementation does not use HTTP client but an <img> tag.

  test('Propagates http client errors during resolve()', () async {
    var uncaught = false;
    var url = 'asdasdasdas';
    cacheManager.throwsNotFound(url);

    await runZoned(
      () async {
        final ImageProvider imageProvider = CachedNetworkImageProvider(
          url,
          cacheManager: cacheManager,
        );
        final caughtError = Completer<bool>();
        FlutterError.onError = (FlutterErrorDetails details) {
          throw Error();
        };
        final result = imageProvider.resolve(ImageConfiguration.empty);
        result.addListener(
          ImageStreamListener(
            (ImageInfo info, bool syncCall) {},
            onError: (Object error, StackTrace? stackTrace) {
              caughtError.complete(true);
            },
          ),
        );
        expect(await caughtError.future, true);
      },
      zoneSpecification: ZoneSpecification(
        handleUncaughtError:
            (
              Zone zone,
              ZoneDelegate zoneDelegate,
              Zone parent,
              Object error,
              StackTrace stackTrace,
            ) {
              uncaught = true;
            },
      ),
    );
    expect(uncaught, false);
  });

  test('Notifies listeners of chunk events', () async {
    final imageAvailable = Completer<void>();
    var url = 'foo';
    var expectedResult = cacheManager.returns(url, kTransparentImage);

    final ImageProvider imageProvider = CachedNetworkImageProvider(
      nonconst('foo'),
      cacheManager: cacheManager,
    );
    final result = imageProvider.resolve(ImageConfiguration.empty);
    final events = <ImageChunkEvent>[];
    result.addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          imageAvailable.complete();
        },
        onChunk: (ImageChunkEvent event) {
          events.add(event);
        },
        onError: (Object error, StackTrace? stackTrace) {
          imageAvailable.completeError(error, stackTrace);
        },
      ),
    );
    await imageAvailable.future;
    expect(events.length, expectedResult.chunks);
    for (var i = 0; i < events.length; i++) {
      expect(
        events[i].cumulativeBytesLoaded,
        math.min((i + 1) * expectedResult.chunkSize, kTransparentImage.length),
      );
      expect(events[i].expectedTotalBytes, kTransparentImage.length);
    }
  }, skip: isBrowser); // Browser loads images through <img> not Http.

  test('Notifies listeners with the image URL as debug label', () async {
    final url = 'debug-label-url';
    cacheManager.returns(url, kTransparentImage);

    final ImageProvider imageProvider = CachedNetworkImageProvider(
      url,
      cacheManager: cacheManager,
    );
    final result = imageProvider.resolve(ImageConfiguration.empty);
    final imageInfo = Completer<ImageInfo>();
    result.addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          imageInfo.complete(image);
        },
        onError: (Object error, StackTrace? stackTrace) {
          imageInfo.completeError(error, stackTrace);
        },
      ),
    );

    expect((await imageInfo.future).debugLabel, url);
  }, skip: isBrowser); // Browser loads images through <img> not Http.
}

class FakeCodec implements Codec {
  @override
  void dispose() {}

  @override
  int get frameCount => throw UnimplementedError();

  @override
  Future<FrameInfo> getNextFrame() {
    throw UnimplementedError();
  }

  @override
  int get repetitionCount => throw UnimplementedError();
}
