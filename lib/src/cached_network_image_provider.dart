import 'dart:async' show Future;
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec, Codec;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

typedef void ErrorListener();

class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  /// Creates an ImageProvider which loads an image from the [url], using the [scale].
  /// When the image fails to load [errorListener] is called.
  const CachedNetworkImageProvider(this.url,
      {this.scale: 1.0, this.errorListener, this.headers, this.cacheManager})
      : assert(url != null),
        assert(scale != null);

  final BaseCacheManager cacheManager;

  /// Web url of the image to load
  final String url;

  /// Scale of the image
  final double scale;

  /// Listener to be called when images fails to load.
  final ErrorListener errorListener;

  // Set headers for the image provider, for example for authentication
  final Map<String, String> headers;

  /// Mock URLs and its respective bytes.
  static final Map<String, Uint8List> _mockUrls = {};

  /// Sets a mock URL.
  ///
  /// When loading an image from the [url], instead of relying on [cacheManager]
  /// to download and cache the file, your [bytes] are going to be used.
  ///
  /// Since there won't be any HTTP request and the SQLite database won't be
  /// reached, this mock can be used to avoid platform-channel interactions.
  ///
  /// Accordingly, the caching features of this library won't apply to the
  /// [url], once nothing is going to be cached after all.
  static void setMockUrl(String url, Uint8List bytes) {
    assert(url != null && url.isNotEmpty);
    assert(bytes != null && bytes.lengthInBytes > 0);
    _mockUrls[url] = bytes;
  }

  /// Clears the mock URLs set through [setMockUrl].
  static void clearMockUrls() => _mockUrls.clear();

  @override
  Future<CachedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return new SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(CachedNetworkImageProvider key) {
    return new MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
// TODO enable information collector on next stable release of flutter
//      informationCollector: () sync* {
//        yield DiagnosticsProperty<ImageProvider>(
//          'Image provider: $this \n Image key: $key',
//          this,
//          style: DiagnosticsTreeStyle.errorProperty,
//        );
//      },
    );
  }

  Future<ui.Codec> _loadAsync(CachedNetworkImageProvider key) async {
    Uint8List bytes;

    if (_mockUrls.containsKey(url)) {
      bytes = _mockUrls[url];
    } else {
      bytes = await _loadBytesWithCacheManager();
    }

    if (bytes.lengthInBytes == 0) {
      if (errorListener != null) errorListener();
      throw new Exception("File was empty");
    }

    return await ui.instantiateImageCodec(bytes);
  }

  Future<Uint8List> _loadBytesWithCacheManager() async {
    var mngr = cacheManager ?? DefaultCacheManager();
    var file = await mngr.getSingleFile(url, headers: headers);

    if (file == null) {
      if (errorListener != null) errorListener();
      return Future<Uint8List>.error("Couldn't download or retrieve file.");
    }

    return await file.readAsBytes();
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final CachedNetworkImageProvider typedOther = other;
    return url == typedOther.url && scale == typedOther.scale;
  }

  @override
  int get hashCode => hashValues(url, scale);

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';
}
