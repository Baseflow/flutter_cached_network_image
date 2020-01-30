import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'base_cached_network_image.dart';
import 'cached_image_widget.dart';

/// Implemented in `browser_poly_image.dart` and `io_poly_image.dart`.
BaseCachedNetworkImage createCachedNetworkImage(
        {Key key,
        @required String imageUrl,
        ImageWidgetBuilder imageBuilder,
        PlaceholderWidgetBuilder placeholder,
        LoadingErrorWidgetBuilder errorWidget,
        Duration fadeOutDuration,
        Curve fadeOutCurve,
        Duration fadeInDuration,
        Curve fadeInCurve,
        double width,
        double height,
        BoxFit fit,
        AlignmentGeometry alignment,
        ImageRepeat repeat,
        bool matchTextDirection,
        final Map<String, String> httpHeaders,
        BaseCacheManager cacheManager,
        bool useOldImageOnUrlChange,
        Color color,
        FilterQuality filterQuality,
        BlendMode colorBlendMode,
        Duration placeholderFadeInDuration}) =>
    throw UnsupportedError('Cannot create without dart:html or dart:io.');
