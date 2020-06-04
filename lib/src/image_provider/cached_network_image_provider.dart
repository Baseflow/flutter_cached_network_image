import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '_image_provider_io.dart'
    if (dart.library.html) '_image_provider_web.dart' as image_provider;

typedef void ErrorListener();

/// Currently there are 2 different ways to show an image on the web with both
/// their own pros and cons, using a custom [HttpGet] (the default for this library)
/// or an HTML Image element mentioned [here on a GitHub issue](https://github.com/flutter/flutter/issues/57187#issuecomment-635637494).
///
/// A custom HttpGet works on Skia and uses the headers when they are provided for
/// the library. In this package is also uses any url transformations that might
/// be executed by the [CachedNetworkImageProvider.cacheManager]. However, this method does require a CORS
/// handshake and will not work for just any image from the web.
///
/// The [HtmlImage] does not need a CORS handshake, but it also does not use your
/// provided headers and it does not work when using Skia to render the page.
enum ImageRenderMethodForWeb{
  HttpGet,
  HtmlImage,
}

abstract class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments [url] and [scale] must not be null.
  /// The [imageRenderMethodForWeb] defines the behavior of the ImageProvider
  /// when compiled for web. See the documentation of [ImageRenderMethodForWeb]
  /// for the benefits of each method.
  const factory CachedNetworkImageProvider(
    String url, {
    double scale,
    @Deprecated('ErrorListener is deprecated, use listeners on the imagestream')
        ErrorListener errorListener,
    Map<String, String> headers,
    BaseCacheManager cacheManager,
    ImageRenderMethodForWeb imageRenderMethodForWeb,
  }) = image_provider.CachedNetworkImageProvider;

  /// Optional cache manager. If no cache manager is defined DefaultCacheManager()
  /// will be used.
  ///
  /// When running flutter on the web, the cacheManager is not used.
  BaseCacheManager get cacheManager;

  @deprecated
  ErrorListener get errorListener;

  /// The URL from which the image will be fetched.
  String get url;

  /// The scale to place in the [ImageInfo] object of the image.
  double get scale;

  /// The HTTP headers that will be used to fetch image from network.
  Map<String, String> get headers;

  @override
  ImageStreamCompleter load(
      CachedNetworkImageProvider key, DecoderCallback decode);
}
