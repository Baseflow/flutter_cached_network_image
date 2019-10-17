import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Decodes the given [File] object as an image, associating it with the given
/// scale. If targetWidth and/or targetHeight are specified the raw image is
/// scaled to match the given dimensions.
///
/// See also:
///
///  * [Image.file] for a shorthand of an [Image] widget backed by [FileImage].
class ScaledFileImage extends ImageProvider<ScaledFileImage> {
  /// Creates an object that decodes a [File] as an image.
  ///
  /// The arguments must not be null.
  const ScaledFileImage(this.file,
      {this.scale = 1.0, this.targetHeight, this.targetWidth})
      : assert(file != null),
        assert(scale != null);

  /// The file to decode into an image.
  final File file;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  /// The targetHeight to which the image is scaled after decoding and before
  /// generating the Image object
  final int targetHeight;

  /// The targetWidth to which the image is scaled after decoding and before
  /// generating the Image object
  final int targetWidth;

  @override
  Future<ScaledFileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<ScaledFileImage>(this);
  }

  @override
  ImageStreamCompleter load(ScaledFileImage key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('Path: ${file?.path}');
      },
    );
  }

  Future<Codec> _loadAsync(ScaledFileImage key) async {
    assert(key == this);

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes == 0) return null;

    return await instantiateImageCodec(bytes,
        targetWidth: targetWidth, targetHeight: targetHeight);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final ScaledFileImage typedOther = other;
    return file?.path == typedOther.file?.path &&
        scale == typedOther.scale &&
        targetWidth == typedOther.targetWidth &&
        targetHeight == typedOther.targetHeight;
  }

  @override
  int get hashCode => hashValues(file?.path, scale);

  @override
  String toString() => '$runtimeType("${file?.path}", scale: $scale, '
      'targetHeight: $targetHeight, targetWidth: $targetWidth)';
}
