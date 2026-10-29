import 'dart:async';
import 'dart:ui' as ui show Codec, FrameInfo;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Slows down animations by this factor to help in development.
double get timeDilation => _timeDilation;
double _timeDilation = 1;

/// An ImageStreamCompleter with support for loading multiple images.
class MultiImageStreamCompleter extends ImageStreamCompleter {
  /// The constructor to create an MultiImageStreamCompleter. The [codec]
  /// should be a stream with the images that should be shown. The
  /// [chunkEvents] should indicate the [ImageChunkEvent]s of the first image
  /// to show.
  ///
  /// Takes ownership of every codec delivered on [codec]; do not reuse them
  /// elsewhere. Replaced codecs, codecs held at disposal, and late results
  /// are disposed by this completer.
  MultiImageStreamCompleter({
    required Stream<ui.Codec> codec,
    required this._scale,
    String? debugLabel,
    Stream<ImageChunkEvent>? chunkEvents,
    InformationCollector? informationCollector,
  }) : _informationCollector = informationCollector {
    this.debugLabel = debugLabel;
    _codecSubscription = codec.listen(
      (event) {
        if (_disposed) {
          event.dispose();
        } else if (_timer != null) {
          _replacePendingCodec(event);
        } else {
          _handleCodecReady(event);
        }
      },
      onError: (Object error, StackTrace stack) {
        reportError(
          context: ErrorDescription('resolving an image codec'),
          exception: error,
          stack: stack,
          informationCollector: informationCollector,
          silent: true,
        );
      },
    );
    if (chunkEvents != null) {
      _chunkSubscription = chunkEvents.listen(
        reportImageChunkEvent,
        onError: (Object error, StackTrace stack) {
          reportError(
            context: ErrorDescription('loading an image'),
            exception: error,
            stack: stack,
            informationCollector: informationCollector,
            silent: true,
          );
        },
      );
    }
  }

  ui.Codec? _codec;
  ui.Codec? _nextImageCodec;
  final double _scale;
  final InformationCollector? _informationCollector;
  ui.FrameInfo? _nextFrame;

  // When the current was first shown.
  Duration? _shownTimestamp;

  // The requested duration for the current frame;
  Duration? _frameDuration;

  // How many frames have been emitted so far.
  int _framesEmitted = 0;
  bool _isDecoding = false;
  Timer? _timer;
  StreamSubscription<ui.Codec>? _codecSubscription;
  StreamSubscription<ImageChunkEvent>? _chunkSubscription;

  // Used to guard against registering multiple _handleAppFrame callbacks for the same frame.
  bool _frameCallbackScheduled = false;

  // Guards asynchronous work after the base class invokes onDisposed.
  bool _disposed = false;

  void _switchToNewCodec() {
    _timer = null;
    _handleCodecReady(_nextImageCodec!);
  }

  void _handleCodecReady(ui.Codec codec) {
    // Every activation supersedes a pending refresh, even when listener
    // removal cancelled its timer before a newer codec arrived.
    _replacePendingCodec(codec);
    _nextImageCodec = null;
    if (_codec != codec) _codec?.dispose();
    _codec = codec;
    _framesEmitted = 0;
    _isDecoding = false;
    // A frame still waiting from the previous codec must not be shown as part
    // of this one.
    _discardNextFrame();

    if (hasListeners) {
      _decodeNextFrameAndSchedule();
    }
  }

  void _handleAppFrame(Duration timestamp) {
    _frameCallbackScheduled = false;
    if (!hasListeners || _nextFrame == null) return;
    if (_isFirstFrame() || _hasFrameDurationPassed(timestamp)) {
      // Transfer ownership before callbacks can remove the last listener.
      final frame = _nextFrame!;
      final codec = _codec!;
      _nextFrame = null;
      _emitFrame(
        ImageInfo(image: frame.image, scale: _scale, debugLabel: debugLabel),
      );
      _shownTimestamp = timestamp;
      _frameDuration = frame.duration;
      if (_disposed || _codec != codec) return;
      if (_framesEmitted % _codec!.frameCount == 0 && _nextImageCodec != null) {
        _switchToNewCodec();
      } else {
        if (!hasListeners) return;
        final completedCycles = _framesEmitted ~/ _codec!.frameCount;
        if (_codec!.repetitionCount == -1 ||
            completedCycles <= _codec!.repetitionCount) {
          _decodeNextFrameAndSchedule();
        } else {
          _timer = null;
        }
      }
      return;
    }
    final delay = _frameDuration! - (timestamp - _shownTimestamp!);
    _timer = Timer(delay * timeDilation, _scheduleAppFrame);
  }

  bool _isFirstFrame() {
    return _frameDuration == null;
  }

  bool _hasFrameDurationPassed(Duration timestamp) {
    return timestamp - _shownTimestamp! >= _frameDuration!;
  }

  Future<void> _decodeNextFrameAndSchedule() async {
    if (_isDecoding) {
      return;
    }
    _isDecoding = true;
    final codec = _codec!;
    final ui.FrameInfo frame;
    try {
      frame = await codec.getNextFrame();
    } on Object catch (exception, stack) {
      if (_disposed || _codec != codec) return;
      _isDecoding = false;
      reportError(
        context: ErrorDescription('resolving an image frame'),
        exception: exception,
        stack: stack,
        informationCollector: _informationCollector,
        silent: true,
      );
      return;
    }
    // Replacing the codec or disposing the completer invalidates this frame.
    if (_disposed || _codec != codec) {
      frame.image.dispose();
      return;
    }
    _isDecoding = false;
    if (codec.frameCount == 1) {
      // This is not an animated image, just return it and don't schedule more
      // frames.
      _emitFrame(
        ImageInfo(image: frame.image, scale: _scale, debugLabel: debugLabel),
      );
      return;
    }
    _discardNextFrame();
    _nextFrame = frame;
    _scheduleAppFrame();
  }

  void _scheduleAppFrame() {
    if (_frameCallbackScheduled) {
      return;
    }
    _frameCallbackScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_handleAppFrame);
  }

  void _emitFrame(ImageInfo imageInfo) {
    // Callbacks may synchronously activate a new codec and reset this count.
    _framesEmitted += 1;
    setImage(imageInfo);
  }

  @override
  void addListener(ImageStreamListener listener) {
    if (!hasListeners && _codec != null) {
      if (_nextFrame != null) {
        // Show the frame decoded while nobody listened instead of skipping it.
        _scheduleAppFrame();
      } else if (_framesEmitted == 0 || _codec!.frameCount > 1) {
        _decodeNextFrameAndSchedule();
      }
    }
    super.addListener(listener);
  }

  @override
  void removeListener(ImageStreamListener listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _replacePendingCodec(ui.Codec? next) {
    final previous = _nextImageCodec;
    _nextImageCodec = next;
    if (previous != next && previous != _codec) previous?.dispose();
  }

  void _discardNextFrame() {
    _nextFrame?.image.dispose();
    _nextFrame = null;
  }

  static void _disposeCodec(ui.Codec codec) => codec.dispose();

  static void _ignoreCodecError(Object error, StackTrace stack) {}

  @override
  void onDisposed() {
    super.onDisposed();
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _discardNextFrame();
    // Cancelling can drop a codec still being created by the producer. Drain
    // late results with static callbacks so the stream cannot retain us.
    _codecSubscription?.onData(_disposeCodec);
    _codecSubscription?.onError(_ignoreCodecError);
    _codecSubscription = null;
    _chunkSubscription?.cancel();
    _chunkSubscription = null;
    _replacePendingCodec(null);
    _codec?.dispose();
    _codec = null;
  }
}
