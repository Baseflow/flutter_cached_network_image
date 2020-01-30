import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'cached_image_widget.dart';

// ignore: uri_does_not_exist
import 'cached_network_image_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) 'browser_cached_network_image.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'io_cached_network_image.dart';

abstract class CachedNetworkImage extends StatefulWidget {
  factory CachedNetworkImage(
          {Key key,
          @required String imageUrl,
          ImageWidgetBuilder imageBuilder,
          PlaceholderWidgetBuilder placeholder,
          LoadingErrorWidgetBuilder errorWidget,
          Duration fadeOutDuration = const Duration(milliseconds: 1000),
          Curve fadeOutCurve: Curves.easeOut,
          Duration fadeInDuration = const Duration(milliseconds: 500),
          Curve fadeInCurve: Curves.easeIn,
          double width,
          double height,
          BoxFit fit,
          AlignmentGeometry alignment: Alignment.center,
          ImageRepeat repeat: ImageRepeat.noRepeat,
          bool matchTextDirection: false,
          final Map<String, String> httpHeaders,
          BaseCacheManager cacheManager,
          bool useOldImageOnUrlChange: false,
          Color color,
          FilterQuality filterQuality: FilterQuality.low,
          BlendMode colorBlendMode,
          Duration placeholderFadeInDuration}) =>
      createCachedNetworkImage(
          key: key,
          imageUrl: imageUrl,
          imageBuilder: imageBuilder,
          placeholder: placeholder,
          errorWidget: errorWidget,
          fadeOutDuration: fadeOutDuration,
          fadeOutCurve: fadeOutCurve,
          fadeInDuration: fadeInDuration,
          fadeInCurve: fadeInCurve,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          repeat: repeat,
          matchTextDirection: matchTextDirection,
          httpHeaders: httpHeaders,
          cacheManager: cacheManager,
          useOldImageOnUrlChange: useOldImageOnUrlChange,
          color: color,
          filterQuality: filterQuality,
          colorBlendMode: colorBlendMode,
          placeholderFadeInDuration: placeholderFadeInDuration);
}
