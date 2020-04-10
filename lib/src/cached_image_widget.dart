import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

typedef Widget ImageWidgetBuilder(
    BuildContext context, ImageProvider imageProvider);
typedef Widget PlaceholderWidgetBuilder(BuildContext context, String url);
typedef Widget ProgressIndicatorBuilder(
    BuildContext context, String url, DownloadProgress progress);
typedef Widget LoadingErrorWidgetBuilder(
    BuildContext context, String url, dynamic error);

class CachedNetworkImage extends StatefulWidget {
  /// Option to use cachemanager with other settings
  final BaseCacheManager cacheManager;

  /// The target image that is displayed.
  final String imageUrl;

  /// Optional builder to further customize the display of the image.
  final ImageWidgetBuilder imageBuilder;

  /// Widget displayed while the target [imageUrl] is loading.
  final PlaceholderWidgetBuilder placeholder;

  /// Widget displayed while the target [imageUrl] is loading.
  final ProgressIndicatorBuilder progressIndicatorBuilder;

  /// Widget displayed while the target [imageUrl] failed loading.
  final LoadingErrorWidgetBuilder errorWidget;

  /// The duration of the fade-in animation for the [placeholder].
  final Duration placeholderFadeInDuration;

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

  /// When set to true it will animate from the old image to the new image
  /// if the url changes.
  final bool useOldImageOnUrlChange;

  /// If non-null, this color is blended with each image pixel using [colorBlendMode].
  final Color color;

  /// Used to combine [color] with this image.
  ///
  /// The default is [BlendMode.srcIn]. In terms of the blend mode, [color] is
  /// the source and this image is the destination.
  ///
  /// See also:
  ///
  ///  * [BlendMode], which includes an illustration of the effect of each blend mode.
  final BlendMode colorBlendMode;

  /// Target the interpolation quality for image scaling.
  ///
  /// If not given a value, defaults to FilterQuality.low.
  final FilterQuality filterQuality;

  CachedNetworkImage({
    Key key,
    @required this.imageUrl,
    this.imageBuilder,
    this.placeholder,
    this.progressIndicatorBuilder,
    this.errorWidget,
    this.fadeOutDuration = const Duration(milliseconds: 1000),
    this.fadeOutCurve = Curves.easeOut,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.fadeInCurve = Curves.easeIn,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    this.httpHeaders,
    this.cacheManager,
    this.useOldImageOnUrlChange = false,
    this.color,
    this.filterQuality = FilterQuality.low,
    this.colorBlendMode,
    this.placeholderFadeInDuration,
  })  : assert(imageUrl != null),
        assert(fadeOutDuration != null),
        assert(fadeOutCurve != null),
        assert(fadeInDuration != null),
        assert(fadeInCurve != null),
        assert(alignment != null),
        assert(filterQuality != null),
        assert(repeat != null),
        assert(matchTextDirection != null),
        super(key: key);

  @override
  CachedNetworkImageState createState() {
    return CachedNetworkImageState();
  }
}

class _ImageTransitionHolder {
  final FileInfo image;
  final DownloadProgress progress;
  AnimationController animationController;
  final Object error;
  Curve curve;
  final TickerFuture forwardTickerFuture;

  _ImageTransitionHolder({
    this.image,
    this.progress,
    @required this.animationController,
    this.error,
    this.curve = Curves.easeIn,
  }) : forwardTickerFuture = animationController.forward();

  void dispose() {
    if (animationController != null) {
      animationController.dispose();
      animationController = null;
    }
  }
}

class CachedNetworkImageState extends State<CachedNetworkImage>
    with TickerProviderStateMixin {
  final _imageHolders = <_ImageTransitionHolder>[];
  Key _streamBuilderKey = UniqueKey();
  Stream<FileResponse> _fileResponseStream;
  FileInfo _fromMemory;

  @override
  Widget build(BuildContext context) {
    return _animatedWidget();
  }

  @override
  void initState() {
    super.initState();
    _createFileStream();
  }

  @override
  void didUpdateWidget(CachedNetworkImage oldWidget) {
    if (oldWidget.imageUrl != widget.imageUrl) {
      _streamBuilderKey = UniqueKey();
      if (!widget.useOldImageOnUrlChange) {
        _disposeImageHolders();
        _imageHolders.clear();
      }
      _createFileStream();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _disposeImageHolders();
    super.dispose();
  }

  void _createFileStream() {
    _fromMemory = _cacheManager().getFileFromMemory(widget.imageUrl);

    _fileResponseStream = _cacheManager()
        .getFileStream(
          widget.imageUrl,
          headers: widget.httpHeaders,
          withProgress: widget.progressIndicatorBuilder != null,
        )
        // ignore errors if not mounted
        .handleError(() {}, test: (_) => !mounted)
        .where((f) {
      if (f is FileInfo) {
        return f?.originalUrl != _fromMemory?.originalUrl ||
            f?.validTill != _fromMemory?.validTill;
      }
      return true;
    });
  }

  void _disposeImageHolders() {
    for (var imageHolder in _imageHolders) {
      imageHolder.dispose();
    }
  }

  void _addImage(
      {FileInfo image,
      DownloadProgress progress,
      Object error,
      Duration duration}) {
    if (_imageHolders.isNotEmpty) {
      var lastHolder = _imageHolders.last;
      if (lastHolder.progress != null && progress != null) {
        _imageHolders.removeLast();
      } else {
        lastHolder.forwardTickerFuture.then((_) {
          if (lastHolder.animationController == null) {
            return;
          }
          if (widget.fadeOutDuration != null) {
            lastHolder.animationController.duration = widget.fadeOutDuration;
          } else {
            lastHolder.animationController.duration =
                const Duration(seconds: 1);
          }
          if (widget.fadeOutCurve != null) {
            lastHolder.curve = widget.fadeOutCurve;
          } else {
            lastHolder.curve = Curves.easeOut;
          }
          lastHolder.animationController.reverse().then((_) {
            _imageHolders.remove(lastHolder);
            if (mounted) setState(() {});
            return null;
          });
        });
      }
    }
    _imageHolders.add(
      _ImageTransitionHolder(
        image: image,
        error: error,
        progress: progress,
        animationController: AnimationController(
          vsync: this,
          duration: duration ??
              (widget.fadeInDuration ?? const Duration(milliseconds: 500)),
        ),
      ),
    );
  }

  Widget _animatedWidget() {
    return StreamBuilder<FileResponse>(
      key: _streamBuilderKey,
      initialData: _fromMemory,
      stream: _fileResponseStream,
      builder: (BuildContext context, AsyncSnapshot<FileResponse> snapshot) {
        if (snapshot.hasError) {
          // error
          if (_imageHolders.isEmpty || _imageHolders.last.error == null) {
            _addImage(image: null, error: snapshot.error);
          }
        } else {
          var fileResponse = snapshot.data;
          if (fileResponse == null) {
            // placeholder
            if (_imageHolders.isEmpty || _imageHolders.last.image != null) {
              DownloadProgress progress;
              if (widget.progressIndicatorBuilder != null) {
                progress = DownloadProgress(widget.imageUrl, null, 0);
              }
              _addImage(
                  progress: progress,
                  image: null,
                  duration: widget.placeholderFadeInDuration ?? Duration.zero);
            }
          } else {
            if (fileResponse is FileInfo) {
              if (_imageHolders.isEmpty ||
                  _imageHolders.last.image?.originalUrl !=
                      fileResponse.originalUrl ||
                  _imageHolders.last.image?.validTill !=
                      fileResponse.validTill) {
                _addImage(
                    image: fileResponse,
                    duration: _imageHolders.isNotEmpty ? null : Duration.zero);
              }
            }
            if (fileResponse is DownloadProgress) {
              _addImage(progress: fileResponse, duration: Duration.zero);
            }
          }
        }

        var children = <Widget>[];
        for (var holder in _imageHolders) {
          if (holder.error != null) {
            children.add(_transitionWidget(
                holder: holder, child: _errorWidget(context, holder.error)));
          } else if (holder.progress != null) {
            children.add(_transitionWidget(
                holder: holder,
                child: widget.progressIndicatorBuilder(
                  context,
                  holder.progress.originalUrl,
                  holder.progress,
                )));
          } else if (holder.image == null) {
            children.add(_transitionWidget(
                holder: holder, child: _placeholder(context)));
          } else {
            children.add(_transitionWidget(
                holder: holder,
                child: KeyedSubtree(
                  key: Key(holder.image.file.path),
                  child: _image(
                    context,
                    FileImage(holder.image.file),
                  ),
                )));
          }
        }

        return Stack(
          fit: StackFit.passthrough,
          alignment: widget.alignment,
          children: children.toList(),
        );
      },
    );
  }

  Widget _transitionWidget({_ImageTransitionHolder holder, Widget child}) {
    return FadeTransition(
      opacity: CurvedAnimation(
          curve: holder.curve, parent: holder.animationController),
      child: child,
    );
  }

  BaseCacheManager _cacheManager() {
    return widget.cacheManager ?? DefaultCacheManager();
  }

  Widget _image(BuildContext context, ImageProvider imageProvider) {
    return widget.imageBuilder != null
        ? widget.imageBuilder(context, imageProvider)
        : Image(
            image: imageProvider,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            alignment: widget.alignment,
            repeat: widget.repeat,
            color: widget.color,
            colorBlendMode: widget.colorBlendMode,
            matchTextDirection: widget.matchTextDirection,
            filterQuality: widget.filterQuality,
          );
  }

  Widget _placeholder(BuildContext context) {
    return widget.placeholder != null
        ? widget.placeholder(context, widget.imageUrl)
        : SizedBox(
            width: widget.width,
            height: widget.height,
          );
  }

  Widget _errorWidget(BuildContext context, Object error) {
    return widget.errorWidget != null
        ? widget.errorWidget(context, widget.imageUrl, error)
        : _placeholder(context);
  }
}
