import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../cached_network_image.dart';

Future<ui.Codec> loadAsyncHtmlImage(
  CachedNetworkImageProvider key,
  StreamController<ImageChunkEvent> chunkEvents,
  DecoderCallback decode,
) {
  final Uri resolved = Uri.base.resolve(key.url);

  return ui.webOnlyInstantiateImageCodecFromUrl(
    // ignore: undefined_function
    resolved,
    chunkCallback: (int bytes, int total) {
      chunkEvents.add(
        ImageChunkEvent(
          cumulativeBytesLoaded: bytes,
          expectedTotalBytes: total,
        ),
      );
    },
  ) as Future<ui.Codec>; // ignore: undefined_function
}
