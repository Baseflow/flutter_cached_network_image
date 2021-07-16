library cached_network_image_web;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image_platform_interface'
        '/cached_network_image_platform_interface.dart' as platform
    show ImageLoader;
import 'package:cached_network_image_platform_interface'
        '/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'dart:ui' as skia;

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
    return _getImage(url);
  }

  Future<skia.Codec> _getImage(String url) {
    final completer = Completer<skia.Codec>();

    final imgElement = html.ImageElement()
      ..src = url
      ..crossOrigin = 'anonymous';
    js_util.setProperty(imgElement, 'decoding', 'async');
    imgElement.decode().then((_) async {
      final canvas = html.CanvasElement(
          width: imgElement.naturalWidth, height: imgElement.naturalHeight);
      canvas.context2D.drawImage(imgElement, 0, 0);
      final blob = await canvas.toBlob('image/png');
      final data = await _getBlobData(blob);
      final codec = await skia.instantiateImageCodec(data);
      completer.complete(codec);
    }).catchError((err) {
      completer.completeError(err);
    });

    return completer.future;
  }

  Future<Uint8List> _getBlobData(html.Blob blob) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    reader.onLoad.listen((_) => completer.complete(reader.result as Uint8List));
    return completer.future;
  }
}
