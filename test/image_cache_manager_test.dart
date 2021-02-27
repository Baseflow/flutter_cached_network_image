import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'dart:async';
import 'package:file/memory.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'image_cache_manager_test.mocks.dart';
import 'fake_cache_manager.dart';
import 'image_data.dart';
import 'rendering_tester.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([CacheManager])
void main() {
  TestRenderingFlutterBinding();

  setUp(() {});

  tearDown(() {
    PaintingBinding.instance?.imageCache?.clear();
    PaintingBinding.instance?.imageCache?.clearLiveImages();
  });

  test('Supplying an ImageCacheManager should call getImageFile', () async {
    var url = 'foo.nl';

    var cacheManager = FakeImageCacheManager();
    cacheManager.returns(url, kTransparentImage);
    final imageAvailable = Completer<void>();

    final ImageProvider imageProvider =
        CachedNetworkImageProvider(url, cacheManager: cacheManager);
    final result = imageProvider.resolve(ImageConfiguration.empty);

    result.addListener(ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        imageAvailable.complete();
      },
    ));
    await imageAvailable.future;

    verify(cacheManager.getImageFile(
      url,
      withProgress: anyNamed('withProgress'),
      headers: anyNamed('headers'),
      key: anyNamed('key'),
    )).called(1);

    verifyNever(cacheManager.getFileStream(
      url,
      withProgress: anyNamed('withProgress'),
      headers: anyNamed('headers'),
      key: anyNamed('key'),
    ));
  }, skip: isBrowser);

  test('Supplying an CacheManager should call getFileStream', () async {
    var url = 'foo.nl';

    var cacheManager = MockCacheManager();
    returns(cacheManager, url, kTransparentImage);
    final imageAvailable = Completer<void>();

    final ImageProvider imageProvider =
        CachedNetworkImageProvider(url, cacheManager: cacheManager);
    final result = imageProvider.resolve(ImageConfiguration.empty);

    result.addListener(ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        imageAvailable.complete();
      },
    ));
    await imageAvailable.future;

    verify(cacheManager.getFileStream(
      url,
      withProgress: anyNamed('withProgress'),
      headers: anyNamed('headers'),
      key: anyNamed('key'),
    )).called(1);
  }, skip: isBrowser);

  test('Supplying an CacheManager with maxHeight throws assertion', () async {
    var url = 'foo.nl';
    final caughtError = Completer<dynamic>();

    var cacheManager = MockCacheManager();
    returns(cacheManager, url, kTransparentImage);
    final imageAvailable = Completer<void>();

    final ImageProvider imageProvider = CachedNetworkImageProvider(url,
        cacheManager: cacheManager, maxHeight: 20);
    final result = imageProvider.resolve(ImageConfiguration.empty);

    result.addListener(
        ImageStreamListener((ImageInfo image, bool synchronousCall) {
      imageAvailable.complete();
    }, onError: (dynamic error, StackTrace? stackTrace) {
      caughtError.complete(error);
    }));
    final dynamic err = await caughtError.future;

    expect(err, isA<AssertionError>());
  }, skip: isBrowser);

  test('Supplying an CacheManager with maxWidth throws assertion', () async {
    var url = 'foo.nl';
    final caughtError = Completer<dynamic>();

    var cacheManager = MockCacheManager();
    returns(cacheManager, url, kTransparentImage);
    final imageAvailable = Completer<void>();

    final ImageProvider imageProvider = CachedNetworkImageProvider(url,
        cacheManager: cacheManager, maxWidth: 20);
    final result = imageProvider.resolve(ImageConfiguration.empty);

    result.addListener(
        ImageStreamListener((ImageInfo image, bool synchronousCall) {
      imageAvailable.complete();
    }, onError: (dynamic error, StackTrace? stackTrace) {
      caughtError.complete(error);
    }));
    final dynamic err = await caughtError.future;

    expect(err, isA<AssertionError>());
  }, skip: isBrowser);
}
ExpectedData returns(
    MockCacheManager cache,
    String url,
    List<int> imageData, {
      Duration? delayBetweenChunks,
    }) {
  const chunkSize = 8;
  final chunks = <Uint8List>[
    for (int offset = 0; offset < imageData.length; offset += chunkSize)
      Uint8List.fromList(imageData.skip(offset).take(chunkSize).toList()),
  ];

  when(cache.getFileStream(
    url,
    withProgress: anyNamed('withProgress'),
    headers: anyNamed('headers'),
    key: anyNamed('key'),
  )).thenAnswer((realInvocation) => createResultStream(
    url,
    chunks,
    imageData,
    delayBetweenChunks,
  ));

  return ExpectedData(
    chunks: chunks.length,
    totalSize: imageData.length,
    chunkSize: chunkSize,
  );
}

Stream<FileResponse> createResultStream(
    String url,
    List<Uint8List> chunks,
    List<int> imageData,
    Duration? delayBetweenChunks,
    ) async* {
  var totalSize = imageData.length;
  var downloaded = 0;
  for (var chunk in chunks) {
    downloaded += chunk.length;
    if (delayBetweenChunks != null) {
      await Future.delayed(delayBetweenChunks);
    }
    yield DownloadProgress(url, totalSize, downloaded);
  }
  var file = MemoryFileSystem().systemTempDirectory.childFile('test.jpg');
  await file.writeAsBytes(imageData);
  yield FileInfo(
      file, FileSource.Online, DateTime.now().add(Duration(days: 1)), url);
}
