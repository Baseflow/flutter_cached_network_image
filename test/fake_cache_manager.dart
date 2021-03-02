// Copyright 2020 Rene Floor. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';

class FakeCacheManager extends Mock implements CacheManager {
  void throwsNotFound(String url) {
    when(this).calls(#getFileStream).withArgs(
      positional: [url],
      named: {
        #key: any,
        #headers: any,
        #withProgress: any,
      },
    ).thenThrow(HttpExceptionWithStatus(404, 'Invalid statusCode: 404',
        uri: Uri.parse(url)));
  }

  ExpectedData returns(
    String url,
    List<int> imageData, {
    Duration? delayBetweenChunks,
  }) {
    const chunkSize = 8;
    final chunks = <Uint8List>[
      for (int offset = 0; offset < imageData.length; offset += chunkSize)
        Uint8List.fromList(imageData.skip(offset).take(chunkSize).toList()),
    ];

    when(this).calls(#getFileStream).withArgs(
      positional: [url],
      named: {
        #key: any,
        #headers: any,
        #withProgress: any,
      },
    ).thenAnswer((_) => _createResultStream(
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

  Stream<FileResponse> _createResultStream(
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
}

class FakeImageCacheManager extends Mock implements ImageCacheManager {
  ExpectedData returns(
    String url,
    List<int> imageData, {
    Duration? delayBetweenChunks,
  }) {
    const chunkSize = 8;
    final chunks = <Uint8List>[
      for (int offset = 0; offset < imageData.length; offset += chunkSize)
        Uint8List.fromList(imageData.skip(offset).take(chunkSize).toList()),
    ];

    when(this).calls(#getImageFile).withArgs(
      positional: [url],
      named: {
        #key: any,
        #headers: any,
        #withProgress: any,
        #maxHeight: any,
        #maxWidth: any,
      },
    ).thenAnswer((_) => _createResultStream(
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

  Stream<FileResponse> _createResultStream(
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
}

class ExpectedData {
  final int chunks;
  final int totalSize;
  final int chunkSize;

  const ExpectedData({required this.chunks, required this.totalSize, required
  this
      .chunkSize,});
}
