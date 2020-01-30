import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'cached_image_widget.dart';
import 'base_cached_network_image.dart';

BaseCachedNetworkImage createCachedNetworkImage(
        {Key key,
        @required String imageUrl,
        ImageWidgetBuilder imageBuilder,
        PlaceholderWidgetBuilder placeholder,
        LoadingErrorWidgetBuilder errorWidget,
        Duration fadeOutDuration,
        Curve fadeOutCurve: Curves.easeOut,
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
    IoCachedNetworkImage(
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

class IoCachedNetworkImage extends BaseCachedNetworkImage {
  final CachedNetworkImage _instance;
  IoCachedNetworkImage({Key key,
      @required String imageUrl,
      ImageWidgetBuilder imageBuilder,
      PlaceholderWidgetBuilder placeholder,
      LoadingErrorWidgetBuilder errorWidget,
      Duration fadeOutDuration,
      Curve fadeOutCurve: Curves.easeOut,
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
      Duration placeholderFadeInDuration})
      : _instance = CachedNetworkImage(
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
  @override
  _IoCachedNetworkImageState createState() => _IoCachedNetworkImageState();
}

class _IoCachedNetworkImageState extends State<IoCachedNetworkImage> {
  @override
  Widget build(BuildContext context) {
    return widget._instance;
  }
}
