import 'dart:ui' as ui;

Future<ui.Codec> createImageCodecFromUrl(
  Uri url, {
  void Function(int cumulativeBytesLoaded, int expectedTotalBytes)?
  chunkCallback,
}) {
  throw UnsupportedError('createImageCodecFromUrl is only available on web');
}
