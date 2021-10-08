library cached_network_image_web;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image_platform_interface'
        '/cached_network_image_platform_interface.dart' as platform
    show ImageBytesBeforeDecoding, ImageLoader;
import 'package:cached_network_image_platform_interface'
        '/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// ImageLoader class to load images on the web platform.
class ImageLoader implements platform.ImageLoader {
  @override
  Stream<ui.Codec> loadAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    Function()? errorListener,
    ImageRenderMethodForWeb imageRenderMethodForWeb,
    Function() evictImage,
    platform.ImageBytesBeforeDecoding? beforeDecoding,
  ) {
    switch (imageRenderMethodForWeb) {
      case ImageRenderMethodForWeb.HttpGet:
        return _loadAsyncHttpGet(
          url,
          cacheKey,
          chunkEvents,
          decode,
          cacheManager,
          maxHeight,
          maxWidth,
          headers,
          errorListener,
          evictImage,
          beforeDecoding,
        );
      case ImageRenderMethodForWeb.HtmlImage:
        return _loadAsyncHtmlImage(url, chunkEvents, decode).asStream();
    }
  }

  Stream<ui.Codec> _loadAsyncHttpGet(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    Function()? errorListener,
    Function() evictImage,
    platform.ImageBytesBeforeDecoding? beforeDecoding,
  ) async* {
    try {
      await for (var result in cacheManager.getFileStream(url,
          withProgress: true, headers: headers)) {
        if (result is DownloadProgress) {
          chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: result.downloaded,
            expectedTotalBytes: result.totalSize,
          ));
        }
        if (result is FileInfo) {
          var file = result.file;
          var bytes = await file.readAsBytes();
          if (beforeDecoding != null) {
            bytes = await beforeDecoding(bytes, url);
          }
          var decoded = await decode(bytes);
          yield decoded;
        }
      }
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        evictImage();
      });

      errorListener?.call();
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }

  Future<ui.Codec> _loadAsyncHtmlImage(
    String url,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) {
    final resolved = Uri.base.resolve(url);

    // ignore: undefined_function
    return ui.webOnlyInstantiateImageCodecFromUrl(
      resolved,
      chunkCallback: (int bytes, int total) {
        chunkEvents.add(
          ImageChunkEvent(
            cumulativeBytesLoaded: bytes,
            expectedTotalBytes: total,
          ),
        );
      },
    ) as Future<ui.Codec>;
  }
}
