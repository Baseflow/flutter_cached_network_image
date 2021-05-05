library cached_network_image_platform_interface;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

enum ImageRenderMethodForWeb {
  /// HtmlImage uses a default web image including default browser caching.
  /// This is the recommended and default choice.
  HtmlImage,

  /// HttpGet uses an http client to fetch an image. It enables the use of
  /// headers, but loses some default web functionality.
  HttpGet,
}


class ImageLoader {
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
    throw UnimplementedError();
  }
}