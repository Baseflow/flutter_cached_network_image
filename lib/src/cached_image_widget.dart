import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

Map<String, FileInfo> _fileCache = new Map<String, FileInfo>();

class CachedNetworkImage extends StatefulWidget {
  /// Option to use cachemanager with other settings
  final BaseCacheManager cacheManager;

  /// Widget displayed while the target [imageUrl] is loading.
  final Widget placeholder;

  /// The target image that is displayed.
  final String imageUrl;

  /// Widget displayed while the target [imageUrl] failed loading.
  final Widget errorWidget;

  /// The duration of the fade-out animation for the [placeholder].
  final Duration fadeOutDuration;

  /// The curve of the fade-out animation for the [placeholder].
  final Curve fadeOutCurve;

  /// The duration of the fade-in animation for the [imageUrl].
  final Duration fadeInDuration;

  /// The curve of the fade-in animation for the [imageUrl].
  final Curve fadeInCurve;

  /// If non-null, require the image to have this width.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder widget does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double width;

  /// If non-null, require the image to have this height.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder widget does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double height;

  /// How to inscribe the image into the space allocated during layout.
  ///
  /// The default varies based on the other fields. See the discussion at
  /// [paintImage].
  final BoxFit fit;

  /// How to align the image within its bounds.
  ///
  /// The alignment aligns the given position in the image to the given position
  /// in the layout bounds. For example, a [Alignment] alignment of (-1.0,
  /// -1.0) aligns the image to the top-left corner of its layout bounds, while a
  /// [Alignment] alignment of (1.0, 1.0) aligns the bottom right of the
  /// image with the bottom right corner of its layout bounds. Similarly, an
  /// alignment of (0.0, 1.0) aligns the bottom middle of the image with the
  /// middle of the bottom edge of its layout bounds.
  ///
  /// If the [alignment] is [TextDirection]-dependent (i.e. if it is a
  /// [AlignmentDirectional]), then an ambient [Directionality] widget
  /// must be in scope.
  ///
  /// Defaults to [Alignment.center].
  ///
  /// See also:
  ///
  ///  * [Alignment], a class with convenient constants typically used to
  ///    specify an [AlignmentGeometry].
  ///  * [AlignmentDirectional], like [Alignment] for specifying alignments
  ///    relative to text direction.
  final AlignmentGeometry alignment;

  /// How to paint any portions of the layout bounds not covered by the image.
  final ImageRepeat repeat;

  /// Whether to paint the image in the direction of the [TextDirection].
  ///
  /// If this is true, then in [TextDirection.ltr] contexts, the image will be
  /// drawn with its origin in the top left (the "normal" painting direction for
  /// children); and in [TextDirection.rtl] contexts, the image will be drawn with
  /// a scaling factor of -1 in the horizontal direction so that the origin is
  /// in the top right.
  ///
  /// This is occasionally used with children in right-to-left environments, for
  /// children that were designed for left-to-right locales. Be careful, when
  /// using this, to not flip children with integral shadows, text, or other
  /// effects that will look incorrect when flipped.
  ///
  /// If this is true, there must be an ambient [Directionality] widget in
  /// scope.
  final bool matchTextDirection;

  // Optional headers for the http request of the image url
  final Map<String, String> httpHeaders;

  CachedNetworkImage({
    Key key,
    this.placeholder,
    @required this.imageUrl,
    this.errorWidget,
    this.fadeOutDuration: const Duration(milliseconds: 300),
    this.fadeOutCurve: Curves.easeOut,
    this.fadeInDuration: const Duration(milliseconds: 700),
    this.fadeInCurve: Curves.easeIn,
    this.width,
    this.height,
    this.fit,
    this.alignment: Alignment.center,
    this.repeat: ImageRepeat.noRepeat,
    this.matchTextDirection: false,
    this.httpHeaders,
    this.cacheManager,
  })  : assert(imageUrl != null),
        assert(fadeOutDuration != null),
        assert(fadeOutCurve != null),
        assert(fadeInDuration != null),
        assert(fadeInCurve != null),
        assert(alignment != null),
        assert(repeat != null),
        assert(matchTextDirection != null),
        super(key: key);

  @override
  CachedNetworkImageState createState() {
    return new CachedNetworkImageState();
  }
}

class _ImageTransitionHolder {
  final FileInfo image;
  final AnimationController animationController;
  final bool hasError;
  Curve curve;
  final TickerFuture forwardTickerFuture;

  _ImageTransitionHolder({
    this.image,
    @required this.animationController,
    this.hasError: false,
    this.curve: Curves.easeIn,
  }) : forwardTickerFuture = animationController.forward();
}

class CachedNetworkImageState extends State<CachedNetworkImage> with TickerProviderStateMixin {
  List<_ImageTransitionHolder> _imageHolders = List();

  @override
  Widget build(BuildContext context) {
    return _animatedWidget();
  }

  _nonAnimatedWidget() {
    return StreamBuilder<FileInfo>(
      initialData: _fileCache[widget.imageUrl],
      stream: _cacheManager().getFile(widget.imageUrl, headers: widget.httpHeaders),
      builder: (BuildContext context, AsyncSnapshot<FileInfo> snapshot) {
        _fileCache[widget.imageUrl] = snapshot.data;
        var fileInfo = snapshot.data;
        if (fileInfo == null) {
          // placeholder
          return _placeholder();
        }
        if (fileInfo.file == null) {
          // error
          return _errorWidget();
        }
        return Image.file(
          fileInfo.file,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          alignment: widget.alignment,
          repeat: widget.repeat,
          matchTextDirection: widget.matchTextDirection,
        );
      },
    );
  }

  _addImage({FileInfo image, bool hasError, Duration duration}) {
    if (_imageHolders.length > 0) {
      var lastHolder = _imageHolders.last;
      if (widget.fadeOutDuration != null) {
        lastHolder.animationController.duration = widget.fadeOutDuration;
      } else {
        lastHolder.animationController.duration = Duration(seconds: 1);
      }
      if (widget.fadeOutCurve != null) {
        lastHolder.curve = widget.fadeOutCurve;
      } else {
        lastHolder.curve = Curves.easeOut;
      }
      lastHolder.forwardTickerFuture.then((_) {
        lastHolder.animationController.reverse().then((_) {
          _imageHolders.remove(lastHolder);
          return null;
        });
      });
    }
    _imageHolders.add(
      _ImageTransitionHolder(
        image: image,
        hasError: hasError ?? false,
        animationController: AnimationController(
          vsync: this,
          duration: duration ?? (widget.fadeInDuration ?? Duration(milliseconds: 500)),
        ),
      ),
    );
  }

  _animatedWidget() {
    return StreamBuilder<FileInfo>(
      initialData: _fileCache[widget.imageUrl],
      stream: _cacheManager().getFile(widget.imageUrl, headers: widget.httpHeaders).where((f) =>
          f?.originalUrl != _fileCache[widget.imageUrl]?.originalUrl ||
          f?.validTill != _fileCache[widget.imageUrl]?.validTill),
      builder: (BuildContext context, AsyncSnapshot<FileInfo> snapshot) {
        _fileCache[widget.imageUrl] = snapshot.data;
        var fileInfo = snapshot.data;
        if (fileInfo == null) {
          // placeholder
          if (_imageHolders.length == 0 || _imageHolders.last.image != null) {
            _addImage(image: null, duration: Duration(milliseconds: 500));
          }
        } else if (fileInfo.file == null) {
          // error
          if (_imageHolders.length == 0 || !_imageHolders.last.hasError) {
            _addImage(image: fileInfo, hasError: true);
          }
        } else if (_imageHolders.length == 0 ||
            _imageHolders.last.image?.originalUrl != fileInfo.originalUrl ||
            _imageHolders.last.image?.validTill != fileInfo.validTill) {
          _addImage(image: fileInfo, duration: _imageHolders.length > 0 ? null : Duration.zero);
        }

        var children = <Widget>[];
        for (var holder in _imageHolders) {
          if (holder.image == null) {
            children.add(_transitionWidget(holder: holder, child: _placeholder()));
          } else if (holder.hasError) {
            children.add(_transitionWidget(holder: holder, child: _errorWidget()));
          } else {
            children.add(_transitionWidget(
              holder: holder,
              child: Image.file(
                holder.image.file,
                fit: widget.fit,
                width: widget.width,
                height: widget.height,
                alignment: widget.alignment,
                repeat: widget.repeat,
                matchTextDirection: widget.matchTextDirection,
              ),
            ));
          }
        }

        return Stack(
          alignment: widget.alignment,
          children: children.reversed.toList(),
        );
      },
    );
  }

  Widget _transitionWidget({_ImageTransitionHolder holder, Widget child}) {
    return FadeTransition(
      opacity: CurvedAnimation(curve: holder.curve, parent: holder.animationController),
      child: child,
    );
  }

  _cacheManager() {
    return widget.cacheManager ?? DefaultCacheManager();
  }

  _placeholder() {
    return widget.placeholder ??
        new SizedBox(
          width: widget.width,
          height: widget.height,
        );
  }

  _errorWidget() {
    return widget.errorWidget ?? _placeholder();
  }
}
