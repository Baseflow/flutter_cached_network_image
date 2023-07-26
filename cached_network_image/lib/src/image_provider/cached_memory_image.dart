import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Image widget to show MemoryImage with caching functionality.
class CachedMemoryImageProvider extends ImageProvider<CachedMemoryImageProvider> {
  ///the cache id use to get cache
  final String tag;

  ///the bytes of image to cache
  final Uint8List img;
  /// CachedMemoryImageProvider shows a memory image lazily using a caching mechanism
  CachedMemoryImageProvider(this.tag, this.img);

  /// Converts a key into an [ImageStreamCompleter], and begins fetching the
  /// image.
  @override
  ImageStreamCompleter loadImage(
      CachedMemoryImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(decode),
      scale: 1.0,
      debugLabel: tag,
      informationCollector: () sync* {
        yield ErrorDescription('Tag: $tag');
      },
    );
  }

  Future<Codec> _loadAsync(ImageDecoderCallback decode) async {
    /// the DefaultCacheManager() encapsulation, it get cache from local storage.
    final Uint8List bytes = img;
    /// The file may become available later.
    if (bytes.lengthInBytes == 0) {
      PaintingBinding.instance.imageCache.evict(this);
      throw StateError('$tag is empty and cannot be loaded as an image.');
    }
    final buffer = await ImmutableBuffer.fromUint8List(bytes);

    return await decode(buffer);
  }

  @override
  Future<CachedMemoryImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedMemoryImageProvider>(this);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    bool res = other is CachedMemoryImageProvider && other.tag == tag;
    return res;
  }

  @override
  int get hashCode => tag.hashCode;

  @override
  String toString() => '${objectRuntimeType(this, 'CachedImageProvider')}("$tag")';
}
