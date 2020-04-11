import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

import '../cached_network_image.dart';

class DefaultImageTransformer extends ImageTransformer {
  final ScaledImageCacheConfig config;

  DefaultImageTransformer(this.config);

  final tmpFileSuffix = '.tmp';

  final _compressionFormats = {
    '.jpg': CompressFormat.jpeg,
    '.jpeg': CompressFormat.jpeg,
    '.webp': CompressFormat.webp,
    '.png': CompressFormat.png,
    '.heic': CompressFormat.heic,
  };
  final _extensionFormats = {
    CompressFormat.jpeg: '.jpg',
    CompressFormat.webp: '.webp',
    CompressFormat.png: '.png',
    CompressFormat.heic: '.heic'
  };

  @override
  Future<FileInfo> transform(FileInfo info, String uri) async {
    final dimens = _getDimensionsFromUrl(uri);
    await _scaleImageFile(info, dimens[0], dimens[1]);
    return info;
  }

  List<int> _getDimensionsFromUrl(String url) {
    Uri uri = Uri.parse(url);
    String heightParam = uri.queryParameters[config.heightKey];
    int height = heightParam != null ? int.tryParse(heightParam) : null;
    String widthParam = uri.queryParameters[config.widthKey];
    int width = widthParam != null ? int.tryParse(widthParam) : null;
    return [width, height];
  }

  Future<FileInfo> _scaleImageFile(FileInfo info, int width, int height) async {
    File file = info.file;
    if (file.existsSync()) {
      String extension = p.extension(file.path) ?? '';
      final format = _compressionFormats[extension] ?? CompressFormat.png;
      final destPath = file.path + tmpFileSuffix +_extensionFormats[format];
      final tmpFile = File(destPath);
      final srcSize = file.lengthSync();
      final screen = window.physicalSize;
      File resizedFile = await FlutterImageCompress.compressAndGetFile(file.path, tmpFile.path,
          minWidth: width ?? screen.width.toInt(),
          minHeight: height ?? screen.height.toInt(),
          format: format);
      if (resizedFile.lengthSync() < srcSize) {
        resizedFile.renameSync(file.path);
      } else {
        resizedFile.deleteSync();
      }
    }
    return info;
  }
}
