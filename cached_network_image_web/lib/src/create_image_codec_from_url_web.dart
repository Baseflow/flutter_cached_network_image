import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

Future<ui.Codec> createImageCodecFromUrl(
  Uri url, {
  void Function(int cumulativeBytesLoaded, int expectedTotalBytes)?
  chunkCallback,
}) {
  return ui_web.createImageCodecFromUrl(url, chunkCallback: chunkCallback);
}
