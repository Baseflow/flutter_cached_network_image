import 'dart:async';
import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as fcm;

/// Manager for getting [CachedImage].
abstract class CacheManager {
  /// Try to get the image from memory directly.
  CachedImage getImageFromMemory(String imageUrl);

  /// Get the image from the cache.
  /// Download form [url] if the cache was missing or expired. And the [headers]
  /// can be used for example for authentication.
  ///
  /// The files are returned as stream. First the cached file if available, when the
  /// cached file is expired the newly downloaded file is returned afterwards.
  Stream<CachedImage> getImage(String url, {Map<String, String> headers});

  /// Try to get the cached image file. Download form [url] when missing.
  Future<File> getImageFile(String url, {Map<String, String> headers});
}

class CachedImage {
  final String originalUrl;
  final DateTime validTill;
  final File file;

  CachedImage(this.originalUrl, this.validTill, this.file);
}

/// Default [CacheManager] implementation by package 'flutter_cache_manager'.
/// See https://pub.dev/packages/flutter_cache_manager for more details.
class DefaultCacheManager implements CacheManager {
  static DefaultCacheManager _instance;

  factory DefaultCacheManager() {
    if (_instance == null) {
      _instance = DefaultCacheManager._(fcm.DefaultCacheManager());
    }
    return _instance;
  }
  final fcm.BaseCacheManager manager;

  DefaultCacheManager._(this.manager);

  @override
  Stream<CachedImage> getImage(String imageUrl, {Map<String, String> headers}) {
    return manager.getFile(imageUrl, headers: headers).map(_convert);
  }

  @override
  CachedImage getImageFromMemory(String imageUrl) {
    return _convert(manager.getFileFromMemory(imageUrl));
  }

  CachedImage _convert(fcm.FileInfo info) {
    if (info == null) return null;
    return CachedImage(info.originalUrl, info.validTill, info.file);
  }

  @override
  Future<File> getImageFile(String url, {Map<String, String> headers}) {
    return manager.getSingleFile(url, headers: headers);
  }
}
