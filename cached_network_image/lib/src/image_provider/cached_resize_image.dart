import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Key used internally by [CachedResizeImage].
///
/// This is used to identify the precise resource in the [imageCache].
class CachedResizeImageKey {
  // Private constructor so nobody from the outside can poison the image cache
  // with this key. It's only accessible to [CachedResizeImage] internally.
  const CachedResizeImageKey(this._providerCacheKey, this._width, this._height);

  final Object _providerCacheKey;
  final int? _width;
  final int? _height;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is CachedResizeImageKey &&
        other._providerCacheKey == _providerCacheKey &&
        other._width == _width &&
        other._height == _height;
  }

  @override
  int get hashCode => hashValues(_providerCacheKey, _width, _height);
}

/// Instructs Flutter to decode the image at the specified dimensions
/// instead of at its native size.
///
/// This allows finer control of the size of the image in [ImageCache] and is
/// generally used to reduce the memory footprint of [ImageCache].
///
/// The decoded image may still be displayed at sizes other than the
/// cached size provided here.
class CachedResizeImage extends ImageProvider<CachedResizeImageKey> {
  /// Creates an ImageProvider that decodes the image to the specified size.
  ///
  /// The cached image will be directly decoded and stored at the resolution
  /// defined by `width` and `height`. The image will lose detail and
  /// use less memory if resized to a size smaller than the native size.
  const CachedResizeImage(
    this.imageProvider, {
    this.width,
    this.height,
    this.allowUpscaling = false,
  })  : assert(width != null || height != null),
        assert(allowUpscaling != null);

  /// The [ImageProvider] that this class wraps.
  final ImageProvider imageProvider;

  /// The width the image should decode to and cache.
  final int? width;

  /// The height the image should decode to and cache.
  final int? height;

  /// Whether the [width] and [height] parameters should be clamped to the
  /// intrinsic width and height of the image.
  ///
  /// In general, it is better for memory usage to avoid scaling the image
  /// beyond its intrinsic dimensions when decoding it. If there is a need to
  /// scale an image larger, it is better to apply a scale to the canvas, or
  /// to use an appropriate [Image.fit].
  final bool allowUpscaling;

  /// Composes the `provider` in a [CachedResizeImage] only when `cacheWidth` and
  /// `cacheHeight` are not both null.
  ///
  /// When `cacheWidth` and `cacheHeight` are both null, this will return the
  /// `provider` directly.
  static ImageProvider<Object> resizeIfNeeded(
      int? cacheWidth, int? cacheHeight, ImageProvider<Object> provider) {
    if (cacheWidth != null || cacheHeight != null) {
      return CachedResizeImage(provider,
          width: cacheWidth, height: cacheHeight);
    }
    return provider;
  }

  @override
  ImageStreamCompleter load(CachedResizeImageKey key, DecoderCallback decode) {
    Future<ui.Codec> decodeResize(Uint8List bytes,
        {int? cacheWidth, int? cacheHeight, bool? allowUpscaling}) {
      assert(
        cacheWidth == null && cacheHeight == null && allowUpscaling == null,
        'CachedResizeImage cannot be composed with another ImageProvider that applies '
        'cacheWidth, cacheHeight, or allowUpscaling.',
      );
      return decode(bytes,
          cacheWidth: width,
          cacheHeight: height,
          allowUpscaling: this.allowUpscaling);
    }

    final ImageStreamCompleter completer =
        imageProvider.load(key._providerCacheKey, decodeResize);
    if (!kReleaseMode) {
      completer.debugLabel =
          '${completer.debugLabel} - Resized(${key._width}×${key._height})';
    }
    return completer;
  }

  @override
  Future<CachedResizeImageKey> obtainKey(ImageConfiguration configuration) {
    Completer<CachedResizeImageKey>? completer;
    // If the imageProvider.obtainKey future is synchronous, then we will be able to fill in result with
    // a value before completer is initialized below.
    SynchronousFuture<CachedResizeImageKey>? result;
    imageProvider.obtainKey(configuration).then((Object key) {
      if (completer == null) {
        // This future has completed synchronously (completer was never assigned),
        // so we can directly create the synchronous result to return.
        result = SynchronousFuture<CachedResizeImageKey>(
            CachedResizeImageKey(key, width, height));
      } else {
        // This future did not synchronously complete.
        completer.complete(CachedResizeImageKey(key, width, height));
      }
    });
    if (result != null) {
      return result!;
    }
    // If the code reaches here, it means the imageProvider.obtainKey was not
    // completed sync, so we initialize the completer for completion later.
    completer = Completer<CachedResizeImageKey>();
    return completer.future;
  }
}
