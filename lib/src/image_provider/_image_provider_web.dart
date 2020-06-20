import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/src/image_provider/multi_image_stream_completer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../cached_network_image.dart' show ImageRenderMethodForWeb;
import '_load_async_web.dart';
import 'cached_network_image_provider.dart' as image_provider;

/// The dart:html implementation of [image_provider.CachedNetworkImageProvider].
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
            imageRenderMethodForWeb ?? ImageRenderMethodForWeb.HtmlImage,
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

  final ImageRenderMethodForWeb _imageRenderMethodForWeb;

  @override
  Future<CachedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(
      image_provider.CachedNetworkImageProvider key, DecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiImageStreamCompleter(
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

  Stream<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) {
    switch (_imageRenderMethodForWeb) {
      case ImageRenderMethodForWeb.HttpGet:
        return _loadAsyncHttpGet(key, chunkEvents, decode);
      case ImageRenderMethodForWeb.HtmlImage:
        return loadAsyncHtmlImage(key, chunkEvents, decode).asStream();
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
