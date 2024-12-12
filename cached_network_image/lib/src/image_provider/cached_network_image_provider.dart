import 'dart:async' show Future, StreamController;
import 'dart:ui' as ui show Codec;

import 'package:cached_network_image/src/image_provider/multi_image_stream_completer.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    if (dart.library.io) '_image_loader.dart'
    if (dart.library.js_interop) 'package:cached_network_image_web/cached_network_image_web.dart'
    show ImageLoader;
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ErrorListener, ImageRenderMethodForWeb;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// IO implementation of the CachedNetworkImageProvider; the ImageProvider to
/// load network images using a cache.
@immutable
class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  /// Creates an ImageProvider which loads an image from the [url], using the [scale].
  /// When the image fails to load [errorListener] is called.
  const CachedNetworkImageProvider(
    this.url, {
    this.maxHeight,
    this.maxWidth,
    this.scale = 1.0,
    this.errorListener,
    this.headers,
    this.cacheManager,
    this.cacheKey,
    this.imageRenderMethodForWeb = ImageRenderMethodForWeb.HttpGet,
  });

  /// CacheManager from which the image files are loaded.
  final BaseCacheManager? cacheManager;

  /// The default cache manager used for image caching.
  static BaseCacheManager defaultCacheManager = DefaultCacheManager();

  /// Web url of the image to load
  final String url;

  /// Cache key of the image to cache
  final String? cacheKey;

  /// Scale of the image
  final double scale;

  /// Listener to be called when images fails to load.
  final ErrorListener? errorListener;

  /// Set headers for the image provider, for example for authentication
  final Map<String, String>? headers;

  /// Maximum height of the loaded image. If not null and using an
  /// [ImageCacheManager] the image is resized on disk to fit the height.
  final int? maxHeight;

  /// Maximum width of the loaded image. If not null and using an
  /// [ImageCacheManager] the image is resized on disk to fit the width.
  final int? maxWidth;

  /// Render option for images on the web platform.
  final ImageRenderMethodForWeb imageRenderMethodForWeb;

  @override
  Future<CachedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @Deprecated('loadBuffer is deprecated, use loadImage instead')
  @override
  ImageStreamCompleter loadBuffer(
    CachedNetworkImageProvider key,
    DecoderBufferCallback decode,
  ) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    final imageStreamCompleter = MultiImageStreamCompleter(
      codec: _loadBufferAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CachedNetworkImageProvider>('Image key', key),
      ],
    );

    if (errorListener != null) {
      imageStreamCompleter.addListener(
        ImageStreamListener(
          (image, synchronousCall) {},
          onError: (Object error, StackTrace? trace) {
            errorListener?.call(error);
          },
        ),
      );
    }

    return imageStreamCompleter;
  }

  @Deprecated('_loadBufferAsync is deprecated, use _loadImageAsync instead')
  Stream<ui.Codec> _loadBufferAsync(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderBufferCallback decode,
  ) {
    assert(key == this);
    return ImageLoader().loadBufferAsync(
      url,
      cacheKey,
      chunkEvents,
      decode,
      cacheManager ?? defaultCacheManager,
      maxHeight,
      maxWidth,
      headers,
      imageRenderMethodForWeb,
      () => PaintingBinding.instance.imageCache.evict(key),
    );
  }

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    final imageStreamCompleter = MultiImageStreamCompleter(
      codec: _loadImageAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CachedNetworkImageProvider>('Image key', key),
      ],
    );

    if (errorListener != null) {
      imageStreamCompleter.addListener(
        ImageStreamListener(
          (image, synchronousCall) {},
          onError: (Object error, StackTrace? trace) {
            errorListener?.call(error);
          },
        ),
      );
    }

    return imageStreamCompleter;
  }

  Stream<ui.Codec> _loadImageAsync(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) {
    assert(key == this);
    return ImageLoader().loadImageAsync(
      url,
      cacheKey,
      chunkEvents,
      decode,
      cacheManager ?? defaultCacheManager,
      maxHeight,
      maxWidth,
      headers,
      imageRenderMethodForWeb,
      () => PaintingBinding.instance.imageCache.evict(key),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is CachedNetworkImageProvider) {
      return ((cacheKey ?? url) == (other.cacheKey ?? other.url)) &&
          scale == other.scale &&
          maxHeight == other.maxHeight &&
          maxWidth == other.maxWidth;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(cacheKey ?? url, scale, maxHeight, maxWidth);

  @override
  String toString() => 'CachedNetworkImageProvider("$url", scale: $scale)';
}
