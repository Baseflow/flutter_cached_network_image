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
        if (__disposed) {
          event.dispose();
          return;
        }

        if (_timer != null) {
          _nextImageCodec = event;
        } else {
          _handleCodecReady(event);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (__disposed) return;
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
  StreamSubscription<ImageChunkEvent>? _chunkSubscription;
  StreamSubscription<ui.Codec>? _codecSubscription;

  // Used to guard against registering multiple _handleAppFrame callbacks for the same frame.
  bool _frameCallbackScheduled = false;

  /// We must avoid disposing a completer if it never had a listener, even
  /// if all [keepAlive] handles get disposed.
  bool __hadAtLeastOneListener = false;

  bool __disposed = false;

  void _switchToNewCodec() {
    _timer = null;
    _handleCodecReady(_nextImageCodec!);
    _nextImageCodec = null;
  }

  void _handleCodecReady(ui.Codec codec) {
    _codec = codec;
    _framesEmitted = 0;
    _isDecoding = false;
    // A frame still waiting from the previous codec must not be shown as part
    // of this one.
    _nextFrame?.image.dispose();
    _nextFrame = null;

    if (hasListeners) {
      _decodeNextFrameAndSchedule();
    }
  }

  void _handleAppFrame(Duration timestamp) {
    _frameCallbackScheduled = false;
    if (!hasListeners || _nextFrame == null) return;
    if (_isFirstFrame() || _hasFrameDurationPassed(timestamp)) {
      _emitFrame(
        ImageInfo(
          image: _nextFrame!.image,
          scale: _scale,
          debugLabel: debugLabel,
        ),
      );
      _shownTimestamp = timestamp;
      _frameDuration = _nextFrame!.duration;
      _nextFrame = null;
      if (_framesEmitted % _codec!.frameCount == 0 && _nextImageCodec != null) {
        _switchToNewCodec();
      } else {
        final completedCycles = _framesEmitted ~/ _codec!.frameCount;
        if (_codec!.repetitionCount == -1 ||
            completedCycles <= _codec!.repetitionCount) {
          _decodeNextFrameAndSchedule();
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
      if (_codec == codec) {
        _isDecoding = false;
      }
      reportError(
        context: ErrorDescription('resolving an image frame'),
        exception: exception,
        stack: stack,
        informationCollector: _informationCollector,
        silent: true,
      );
      return;
    }
    // A newer codec replaced this one while decoding; it resets _isDecoding.
    if (_codec != codec) {
      frame.image.dispose();
      return;
    }
    _isDecoding = false;
    if (__disposed) {
      frame.image.dispose();
      return;
    }
    if (codec.frameCount == 1) {
      // This is not an animated image, just return it and don't schedule more
      // frames.
      _emitFrame(
        ImageInfo(image: frame.image, scale: _scale, debugLabel: debugLabel),
      );
      return;
    }
    _nextFrame?.image.dispose();
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
    setImage(imageInfo);
    _framesEmitted += 1;
  }

  @override
  void addListener(ImageStreamListener listener) {
    __hadAtLeastOneListener = true;
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
      __maybeDispose();
    }
  }

  int __keepAliveHandles = 0;

  @override
  ImageStreamCompleterHandle keepAlive() {
    final delegateHandle = super.keepAlive();
    return _MultiImageStreamCompleterHandle(this, delegateHandle);
  }

  void __maybeDispose() {
    if (!__hadAtLeastOneListener ||
        __disposed ||
        hasListeners ||
        __keepAliveHandles != 0) {
      return;
    }

    __disposed = true;
    _codecSubscription?.cancel();
    _codecSubscription = null;
    _chunkSubscription?.onData(null);
    _chunkSubscription?.cancel();
    _chunkSubscription = null;
  }
}

class _MultiImageStreamCompleterHandle implements ImageStreamCompleterHandle {
  _MultiImageStreamCompleterHandle(this._completer, this._delegateHandle) {
    _completer!.__keepAliveHandles += 1;
  }

  MultiImageStreamCompleter? _completer;
  final ImageStreamCompleterHandle _delegateHandle;

  /// Call this method to signal the [ImageStreamCompleter] that it can now be
  /// disposed when its last listener drops.
  ///
  /// This method must only be called once per object.
  @override
  void dispose() {
    assert(_completer != null);
    assert(_completer!.__keepAliveHandles > 0);
    assert(!_completer!.__disposed);

    _delegateHandle.dispose();

    _completer!.__keepAliveHandles -= 1;
    _completer!.__maybeDispose();
    _completer = null;
  }
}
