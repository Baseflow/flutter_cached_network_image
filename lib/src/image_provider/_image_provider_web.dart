// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../cached_network_image.dart' show ImageRenderMethodForWeb;
import 'cached_network_image_provider.dart' as image_provider;

/// The dart:html implementation of [test_image.TestImage].
///
/// TestImage on the web does not support decoding to a specified size.
class CachedNetworkImageProvider
    extends ImageProvider<image_provider.CachedNetworkImageProvider>
    implements image_provider.CachedNetworkImageProvider {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments [url] and [scale] must not be null.
  const CachedNetworkImageProvider(
    this.url, {
    this.scale = 1.0,
    this.errorListener,
    this.headers,
    this.cacheManager,
    ImageRenderMethodForWeb imageRenderMethodForWeb,
  })  : _imageRenderMethodForWeb =
            imageRenderMethodForWeb ?? ImageRenderMethodForWeb.HttpGet,
        assert(url != null),
        assert(scale != null);

  @override
  final BaseCacheManager cacheManager;

  @override
  final String url;

  @override
  final double scale;

  /// Listener to be called when images fails to load.
  @override
  final image_provider.ErrorListener errorListener;

  @override
  final Map<String, String> headers;

  @override
  final ImageRenderMethodForWeb _imageRenderMethodForWeb;

  @override
  Future<CachedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(
      image_provider.CachedNetworkImageProvider key, DecoderCallback decode) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
        chunkEvents: chunkEvents.stream,
        codec:
            _loadAsync(key as CachedNetworkImageProvider, chunkEvents, decode),
        scale: key.scale,
        informationCollector: _imageStreamInformationCollector(key));
  }

  InformationCollector _imageStreamInformationCollector(
      image_provider.CachedNetworkImageProvider key) {
    InformationCollector collector;
    assert(() {
      collector = () {
        return <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', this),
          DiagnosticsProperty<CachedNetworkImageProvider>(
              'Image key', key as CachedNetworkImageProvider),
        ];
      };
      return true;
    }());
    return collector;
  }

  Future<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) {
    switch (_imageRenderMethodForWeb) {
      case ImageRenderMethodForWeb.HttpGet:
        return _loadAsyncHttpGet(key, chunkEvents, decode).first;
      case ImageRenderMethodForWeb.HtmlImage:
        return _loadAsyncHtmlImage(key, chunkEvents, decode);
    }
    throw UnsupportedError(
        'ImageRenderMethod $_imageRenderMethodForWeb is not supported');
  }

  Stream<ui.Codec> _loadAsyncHttpGet(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) async* {
    assert(key == this);
    try {
      var mngr = cacheManager ?? DefaultCacheManager();
      await for (var result in mngr.getFileStream(key.url,
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
      errorListener?.call();
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }

  Future<ui.Codec> _loadAsyncHtmlImage(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) {
    assert(key == this);

    final Uri resolved = Uri.base.resolve(key.url);

    // ignore: undefined_function
    return ui.webOnlyInstantiateImageCodecFromUrl(
      resolved,
      chunkCallback: (int bytes, int total) {
        chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: bytes, expectedTotalBytes: total));
      },
    ) as Future<ui.Codec>; // ignore: undefined_function
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CachedNetworkImageProvider &&
        other.url == url &&
        other.scale == scale;
  }

  @override
  int get hashCode => ui.hashValues(url, scale);

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';
}
