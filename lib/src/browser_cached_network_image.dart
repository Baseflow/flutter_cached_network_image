import 'package:flutter/material.dart';
import 'base_cached_network_image.dart';
import 'cached_image_types.dart';

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
        bool useOldImageOnUrlChange,
        Color color,
        FilterQuality filterQuality,
        BlendMode colorBlendMode,
        Duration placeholderFadeInDuration}) =>
    BrowserCachedNetworkImage(
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
        useOldImageOnUrlChange: useOldImageOnUrlChange,
        color: color,
        filterQuality: filterQuality,
        colorBlendMode: colorBlendMode,
        placeholderFadeInDuration: placeholderFadeInDuration);

class BrowserCachedNetworkImage extends BaseCachedNetworkImage {
  final Image _instance;
  BrowserCachedNetworkImage(
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
      bool useOldImageOnUrlChange,
      Color color,
      FilterQuality filterQuality,
      BlendMode colorBlendMode,
      Duration placeholderFadeInDuration})
      : _instance = Image.network(imageUrl,
            key: key,
            width: width,
            height: height,
            color: color,
            colorBlendMode: colorBlendMode,
            fit: fit,
            alignment: alignment,
            repeat: repeat,
            filterQuality: filterQuality,
            headers: httpHeaders);

  @override
  _BrowserCachedNetworkImageState createState() =>
      _BrowserCachedNetworkImageState();
}

class _BrowserCachedNetworkImageState extends State<BrowserCachedNetworkImage> {
  @override
  Widget build(BuildContext context) {
    return widget._instance;
  }
}
