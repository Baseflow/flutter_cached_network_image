/// Web implementation of CachedNetworkImage
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image_platform_interface'
    '/cached_network_image_platform_interface.dart'
    as platform
    show ImageLoader, ImageRenderMethodForWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'src/create_image_codec_from_url_stub.dart'
    if (dart.library.ui_web) 'src/create_image_codec_from_url_web.dart';

/// ImageLoader class to load images on the web platform.
class ImageLoader implements platform.ImageLoader {
  @Deprecated('Use loadImageAsync instead')
  @override
  Stream<ui.Codec> loadBufferAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderBufferCallback decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    platform.ImageRenderMethodForWeb imageRenderMethodForWeb,
    VoidCallback evictImage,
  ) {
    return _load(
      url,
      cacheKey,
      chunkEvents,
      (bytes) async {
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      },
      cacheManager,
      maxHeight,
      maxWidth,
      headers,
      imageRenderMethodForWeb,
      evictImage,
    );
  }

  @override
  Stream<ui.Codec> loadImageAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    platform.ImageRenderMethodForWeb imageRenderMethodForWeb,
    VoidCallback evictImage,
  ) {
    return _load(
      url,
      cacheKey,
      chunkEvents,
      (bytes) async {
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      },
      cacheManager,
      maxHeight,
      maxWidth,
      headers,
      imageRenderMethodForWeb,
      evictImage,
    );
  }

  Stream<ui.Codec> _load(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    _FileDecoderCallback decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    platform.ImageRenderMethodForWeb imageRenderMethodForWeb,
    VoidCallback evictImage,
  ) {
    switch (imageRenderMethodForWeb) {
      case platform.ImageRenderMethodForWeb.HttpGet:
        return _loadAsyncHttpGet(
          url,
          cacheKey,
          chunkEvents,
          decode,
          cacheManager,
          maxHeight,
          maxWidth,
          headers,
          evictImage,
        );
      case platform.ImageRenderMethodForWeb.HtmlImage:
        return _loadAsyncHtmlImage(url, chunkEvents).asStream();
    }
  }

  Stream<ui.Codec> _loadAsyncHttpGet(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    _FileDecoderCallback decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    VoidCallback evictImage,
  ) {
    final streamController = StreamController<ui.Codec>();

    var downloadDone = false;
    var pendingDecodes = 0;
    var finished = false;
    var settling = false;
    var decoded = false;
    (Object, StackTrace)? decodeFailure;
    (Object, StackTrace)? downloadFailure;

    void finish() {
      if (finished) return;
      finished = true;
      streamController.close();
      chunkEvents.close();
    }

    void fail(Object e, StackTrace st) {
      if (finished) return;
      scheduleMicrotask(() {
        evictImage();
      });
      streamController.addError(e, st);
      finish();
    }

    // Runs once the download is over and every decode has finished, so a
    // stale file that fails to decode is only fatal when no fresh file came.
    Future<void> settle() async {
      final failure = downloadFailure ?? (decoded ? null : decodeFailure);
      if (decodeFailure != null && !decoded) {
        try {
          // Drop the broken entry so the next attempt downloads it again.
          await cacheManager.removeFile(cacheKey ?? url);
        } on Object catch (_) {
          // Keep the original error visible.
        }
      }
      if (failure == null) {
        finish();
      } else {
        fail(failure.$1, failure.$2);
      }
    }

    void closeIfComplete() {
      if (settling || !downloadDone || pendingDecodes > 0) return;
      settling = true;
      unawaited(settle());
    }

    Future<void> decodeFile(FileInfo info) async {
      try {
        final bytes = await info.file.readAsBytes();
        final codec = await decode(bytes);
        if (finished) {
          codec.dispose();
        } else {
          decoded = true;
          streamController.add(codec);
        }
      } on Object catch (e, st) {
        decodeFailure = (e, st);
      } finally {
        pendingDecodes--;
        closeIfComplete();
      }
    }

    try {
      final stream = cacheManager.getFileStream(
        url,
        withProgress: true,
        headers: headers,
        key: cacheKey,
      );

      stream.listen(
        (event) {
          if (event is DownloadProgress) {
            chunkEvents.add(
              ImageChunkEvent(
                cumulativeBytesLoaded: event.downloaded,
                expectedTotalBytes: event.totalSize,
              ),
            );
          }
          if (event is FileInfo) {
            pendingDecodes++;
            unawaited(decodeFile(event));
          }
        },
        onError: (Object e, StackTrace st) {
          downloadFailure = (e, st);
          downloadDone = true;
          closeIfComplete();
        },
        onDone: () {
          downloadDone = true;
          closeIfComplete();
        },
        cancelOnError: true,
      );
    } on Object catch (e, st) {
      fail(e, st);
    }

    return streamController.stream;
  }

  Future<ui.Codec> _loadAsyncHtmlImage(
    String url,
    StreamController<ImageChunkEvent> chunkEvents,
  ) {
    final resolved = Uri.base.resolve(url);
    return createImageCodecFromUrl(
      resolved,
      chunkCallback: (int bytes, int total) {
        chunkEvents.add(
          ImageChunkEvent(
            cumulativeBytesLoaded: bytes,
            expectedTotalBytes: total,
          ),
        );
      },
    );
  }
}

typedef _FileDecoderCallback = Future<ui.Codec> Function(Uint8List);
