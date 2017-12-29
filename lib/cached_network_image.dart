library cached_network_image;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui show Image, decodeImageFromList;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/**
 *  CachedNetworkImage for Flutter
 *
 *  Copyright (c) 2017 Rene Floor
 *
 *  Released under MIT License.
 */

class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  const CachedNetworkImageProvider(this.url, {this.scale: 1.0})
      : assert(url != null),
        assert(scale != null);

  final String url;

  final double scale;

  @override
  Future<CachedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return new SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(CachedNetworkImageProvider key) {
    return new OneFrameImageStreamCompleter(_loadAsync(key),
        informationCollector: (StringBuffer information) {
      information.writeln('Image provider: $this');
      information.write('Image key: $key');
    });
  }

  Future<ImageInfo> _loadAsync(CachedNetworkImageProvider key) async {
    var cacheManager = await CacheManager.getInstance();
    var file = await cacheManager.getFile(url);
    return _loadAsyncFromFile(key, file);
  }

  Future<ImageInfo> _loadAsyncFromFile(
      CachedNetworkImageProvider key, File file) async {
    assert(key == this);

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes == 0) return null;

    final ui.Image image = await decodeImageFromList(bytes);
    if (image == null) return null;

    return new ImageInfo(
      image: image,
      scale: key.scale,
    );
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
