import 'dart:async' show Future, StreamController;
import 'dart:io' show File;
import 'dart:ui' as ui show instantiateImageCodec, Codec;

import 'package:cached_network_image/src/image_provider/multi_image_stream_completer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

typedef void ErrorListener();

class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  /// Creates an ImageProvider which loads an image from the [url], using the [scale].
  /// When the image fails to load [errorListener] is called.
  const CachedNetworkImageProvider(this.url,
      {this.scale = 1.0, this.errorListener, this.headers, this.cacheManager})
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

  @override
  Future<CachedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(
      CachedNetworkImageProvider key, DecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();
    return MultiImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>(
          'Image provider: $this \n Image key: $key',
          this,
          style: DiagnosticsTreeStyle.errorProperty,
        );
      },
    );
  }

  Stream<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) async* {
    assert(key == this);
    try {
      var mngr = cacheManager ?? DefaultCacheManager();
      await for (var result
          in mngr.getFileStream(key.url, withProgress: true)) {
        if (result is DownloadProgress) {
          chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: result.downloaded,
            expectedTotalBytes: result.totalSize,
          ));
        }
        if (result is FileInfo) {
          var file = result.file;
          var bytes = await file.readAsBytes();
          yield await decode(bytes);
        }
      }
    } finally {
      await chunkEvents.close();
    }
  }

  Future<ui.Codec> _loadAsyncFromFile(
      CachedNetworkImageProvider key, File file) async {
    assert(key == this);

    final bytes = await file.readAsBytes();

    if (bytes.lengthInBytes == 0) {
      if (errorListener != null) errorListener();
      throw Exception('File was empty');
    }

    return ui.instantiateImageCodec(bytes);
  }

  @override
  bool operator ==(dynamic other) {
    if (other is CachedNetworkImageProvider) {
      return url == other.url && scale == other.scale;
    }
    return false;
  }

  @override
  int get hashCode => hashValues(url, scale);

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';
}
